import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/services/token_storage.dart';
import '../../../messages/presentation/screens/chat_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<List<Map<String, dynamic>>> _notifications;

  @override
  void initState() {
    super.initState();
    _notifications = _loadNotifications();
  }

  Future<Options> _authorizedOptions() async {
    final token = await const TokenStorage().getToken();
    return Options(headers: {'Authorization': 'Token $token'});
  }

  Future<List<Map<String, dynamic>>> _loadNotifications() async {
    final response = await Dio().get(
      '${ApiClient.baseUrl}/notifications/',
      options: await _authorizedOptions(),
    );
    final body = response.data;
    final items = body is Map ? body['results'] : body;
    if (items is! List) return const [];
    return items.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  Future<void> _refresh() async {
    final notifications = _loadNotifications();
    setState(() => _notifications = notifications);
    await notifications;
  }

  Future<void> _openNotification(Map<String, dynamic> notification) async {
    final notificationId = _integer(notification['id']);
    if (notificationId != null && notification['is_read'] != true) {
      setState(() => notification['is_read'] = true);
      try {
        await Dio().patch(
          '${ApiClient.baseUrl}/notifications/$notificationId/',
          data: {'is_read': true},
          options: await _authorizedOptions(),
        );
      } on DioException {
        // The user can still open the destination when the read receipt fails.
      }
    }

    final conversationId = _integer(notification['conversation']);
    if (notification['notification_type'] != 'message' || conversationId == null) {
      return;
    }

    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          conversationId: conversationId,
          sellerName: notification['sender']?.toString() ?? 'Conversation',
        ),
      ),
    );
    if (mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _notifications,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: TextButton(
                onPressed: _refresh,
                child: const Text('Could not load notifications. Try again.'),
              ),
            );
          }
          final notifications = snapshot.data ?? const [];
          if (notifications.isEmpty) {
            return const Center(child: Text('You are all caught up.'));
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              itemCount: notifications.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final notification = notifications[index];
                final isUnread = notification['is_read'] != true;
                final isMessage = notification['notification_type'] == 'message';
                return ListTile(
                  leading: CircleAvatar(
                    child: Icon(isMessage ? Icons.chat_bubble_outline : Icons.notifications_outlined),
                  ),
                  title: Text(
                    notification['message']?.toString() ?? 'New activity',
                    style: isUnread ? const TextStyle(fontWeight: FontWeight.bold) : null,
                  ),
                  subtitle: isMessage ? const Text('Tap to open conversation') : null,
                  trailing: isMessage ? const Icon(Icons.chevron_right) : null,
                  onTap: () => _openNotification(notification),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

int? _integer(dynamic value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '');
}
