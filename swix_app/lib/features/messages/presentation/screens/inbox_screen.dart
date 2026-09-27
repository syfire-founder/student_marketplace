import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/services/token_storage.dart';
import 'chat_screen.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  late Future<List<Map<String, dynamic>>> _conversations;

  @override
  void initState() {
    super.initState();
    _conversations = _loadConversations();
  }

  Future<List<Map<String, dynamic>>> _loadConversations() async {
    final token = await const TokenStorage().getToken();
    final response = await Dio().get(
      '${ApiClient.baseUrl}/conversations/',
      options: Options(headers: {'Authorization': 'Token $token'}),
    );
    final body = response.data;
    final items = body is Map ? body['results'] : body;
    if (items is! List) return const [];
    return items.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  Future<void> _refresh() async {
    final conversations = _loadConversations();
    setState(() => _conversations = conversations);
    await conversations;
  }

  Future<void> _markConversationRead(int conversationId) async {
    final token = await const TokenStorage().getToken();
    await Dio().post(
      '${ApiClient.baseUrl}/conversations/$conversationId/mark-read/',
      options: Options(headers: {'Authorization': 'Token $token'}),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _conversations,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: TextButton(
                onPressed: _refresh,
                child: const Text('Could not load inbox. Try again.'),
              ),
            );
          }
          final conversations = snapshot.data ?? const [];
          if (conversations.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No conversations yet. Contact a seller to start one.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: conversations.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final conversation = conversations[index];
                final id = _integer(conversation['id']);
                final otherParticipant = conversation['other_participant'];
                final name = otherParticipant is Map
                    ? otherParticipant['username']?.toString() ?? 'Campus seller'
                    : 'Campus seller';
                final latestMessage = conversation['latest_message'];
                final preview = latestMessage is Map
                    ? '${latestMessage['sender'] ?? name}: ${latestMessage['text'] ?? ''}'
                    : 'Tap to view conversation';
                final unreadCount = _integer(conversation['unread_count']) ?? 0;
                return ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.person_outline),
                  ),
                  title: Text(
                    name,
                    style: unreadCount > 0
                        ? const TextStyle(fontWeight: FontWeight.bold)
                        : null,
                  ),
                  subtitle: Text(preview, maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: unreadCount > 0
                      ? _UnreadBadge(count: unreadCount)
                      : const Icon(Icons.chevron_right),
                  onTap: id == null
                      ? null
                      : () async {
                          if (unreadCount > 0) {
                            setState(() => conversation['unread_count'] = 0);
                            _markConversationRead(id).catchError((_) {});
                          }
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                conversationId: id,
                                sellerName: name,
                              ),
                            ),
                          );
                          if (mounted) _refresh();
                        },
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: 12,
    backgroundColor: Theme.of(context).colorScheme.primary,
    foregroundColor: Theme.of(context).colorScheme.onPrimary,
    child: Text(
      count > 99 ? '99+' : '$count',
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
    ),
  );
}

int? _integer(dynamic value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '');
}
