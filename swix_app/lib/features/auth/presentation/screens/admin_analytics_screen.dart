import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/services/token_storage.dart';

class AdminAnalyticsScreen extends StatefulWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  State<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends State<AdminAnalyticsScreen> {
  late Future<Map<String, dynamic>> _analytics;

  @override
  void initState() {
    super.initState();
    _analytics = _loadAnalytics();
  }

  Future<Map<String, dynamic>> _loadAnalytics() async {
    final token = await const TokenStorage().getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Please sign in again with the administrator account.');
    }
    final response = await Dio().get(
      '${ApiClient.baseUrl}/admin-analytics/',
      options: Options(headers: {'Authorization': 'Token $token'}),
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<void> _refresh() async {
    final request = _loadAnalytics();
    setState(() => _analytics = request);
    await request;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('App analytics'),
        actions: [
          IconButton(
            tooltip: 'Refresh analytics',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _analytics,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Could not load analytics.'),
                    const SizedBox(height: 12),
                    FilledButton(onPressed: _refresh, child: const Text('Retry')),
                  ],
                ),
              ),
            );
          }
          final data = snapshot.data!;
          final users = _mapItems(data['users_registered_daily']);
          final visits = _mapItems(data['app_visits_daily']);
          final categories = _mapItems(data['business_profiles_by_category']);
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('All time', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _MetricCard(
                        label: 'Registered users',
                        value: '${data['total_users'] ?? 0}',
                        icon: Icons.people_outline,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MetricCard(
                        label: 'Business profiles',
                        value: '${data['total_business_profiles'] ?? 0}',
                        icon: Icons.storefront_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _DailySection(title: 'App visits · last 30 days', rows: visits),
                const SizedBox(height: 24),
                _DailySection(title: 'New users · last 30 days', rows: users),
                const SizedBox(height: 24),
                Text('Business profiles by category',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                if (categories.isEmpty)
                  const Card(child: ListTile(title: Text('No categories yet.')))
                else
                  ...categories.map(
                    (item) => Card(
                      child: ListTile(
                        leading: const Icon(Icons.category_outlined),
                        title: Text(item['category']?.toString() ?? 'Other'),
                        trailing: Text(
                          '${item['count'] ?? 0}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(value, style: Theme.of(context).textTheme.headlineSmall),
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _DailySection extends StatelessWidget {
  const _DailySection({required this.title, required this.rows});

  final String title;
  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    final shownRows = rows;
    final maximum = shownRows.fold<int>(
      0,
      (maxValue, row) => maxValue > (_asInt(row['count']) ?? 0)
          ? maxValue
          : (_asInt(row['count']) ?? 0),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: shownRows.reversed.map((row) {
                final count = _asInt(row['count']) ?? 0;
                final date = DateTime.tryParse(row['date']?.toString() ?? '');
                final dateLabel = date == null
                    ? row['date']?.toString() ?? ''
                    : '${date.month}/${date.day}';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      SizedBox(width: 42, child: Text(dateLabel)),
                      Expanded(
                        child: LinearProgressIndicator(
                          value: maximum == 0 ? 0 : count / maximum,
                          minHeight: 10,
                        ),
                      ),
                      SizedBox(
                        width: 36,
                        child: Text('$count', textAlign: TextAlign.end),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

int? _asInt(dynamic value) => value is int ? value : int.tryParse(value?.toString() ?? '');

List<Map<String, dynamic>> _mapItems(dynamic value) => value is List
    ? value.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList()
    : const [];
