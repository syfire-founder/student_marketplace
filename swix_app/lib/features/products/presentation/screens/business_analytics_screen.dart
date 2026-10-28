import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/services/token_storage.dart';
import '../../../auth/presentation/screens/create_business_screen.dart';

class BusinessAnalyticsScreen extends StatefulWidget {
  const BusinessAnalyticsScreen({super.key});

  @override
  State<BusinessAnalyticsScreen> createState() =>
      _BusinessAnalyticsScreenState();
}

class _BusinessAnalyticsScreenState extends State<BusinessAnalyticsScreen> {
  late Future<Map<String, dynamic>> _analytics;

  @override
  void initState() {
    super.initState();
    _analytics = _loadAnalytics();
  }

  Future<Map<String, dynamic>> _loadAnalytics() async {
    final token = await const TokenStorage().getToken();
    if (token == null || token.isEmpty) throw Exception('Please sign in again.');
    final response = await Dio().get(
      '${ApiClient.baseUrl}/business-dashboard/',
      options: Options(headers: {'Authorization': 'Token $token'}),
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<void> _refresh() async {
    final request = _loadAnalytics();
    setState(() => _analytics = request);
    await request;
  }

  Future<void> _createBusiness() async {
    final created = await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CreateBusinessScreen()),
    );
    if (created != null && mounted) {
      setState(() => _analytics = _loadAnalytics());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Business analytics'),
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
            final error = snapshot.error;
            final noBusiness = error is DioException &&
                error.response?.statusCode == 400 &&
                error.response?.data is Map &&
                (error.response!.data as Map)['detail']
                        ?.toString()
                        .contains('business profile') ==
                    true;
            if (noBusiness) return _NoBusinessView(onCreate: _createBusiness);
            return _LoadErrorView(onRetry: _refresh);
          }
          return _AnalyticsContent(
            data: snapshot.data!,
            onRefresh: _refresh,
          );
        },
      ),
    );
  }
}

class _NoBusinessView extends StatelessWidget {
  const _NoBusinessView({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.storefront_outlined, size: 56),
            const SizedBox(height: 16),
            Text(
              'Set up your business first',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Create a business profile to see followers, views, reviews, and listing performance.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_business_outlined),
              label: const Text('Create business profile'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadErrorView extends StatelessWidget {
  const _LoadErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 48),
            const SizedBox(height: 12),
            const Text('Could not load business analytics.'),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}

class _AnalyticsContent extends StatelessWidget {
  const _AnalyticsContent({required this.data, required this.onRefresh});

  final Map<String, dynamic> data;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final topProducts = _mapList(data['top_products']);
    final trending = _mapList(data['trending_products']);
    final reviews = _mapList(data['recent_reviews']);
    final width = MediaQuery.sizeOf(context).width;
    final cardWidth = (width - 52) / 2;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          Text(
            data['business']?.toString() ?? 'Your business',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text('An overview of your business activity.'),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _MetricCard(
                width: cardWidth,
                icon: Icons.visibility_outlined,
                label: 'Total views',
                value: _value(data['total_views']),
              ),
              _MetricCard(
                width: cardWidth,
                icon: Icons.people_outline,
                label: 'Followers',
                value: _value(data['followers']),
              ),
              _MetricCard(
                width: cardWidth,
                icon: Icons.inventory_2_outlined,
                label: 'Listings',
                value: _value(data['products']),
              ),
              _MetricCard(
                width: cardWidth,
                icon: Icons.favorite_border,
                label: 'Favorites',
                value: _value(data['favorites']),
              ),
              _MetricCard(
                width: cardWidth,
                icon: Icons.star_outline,
                label: 'Average rating',
                value: _rating(data['average_rating']),
              ),
              _MetricCard(
                width: cardWidth,
                icon: Icons.rate_review_outlined,
                label: 'Reviews',
                value: _value(data['reviews']),
              ),
            ],
          ),
          const SizedBox(height: 28),
          _SectionTitle(title: 'Top listings'),
          if (topProducts.isEmpty)
            const _EmptySection(text: 'Views will appear after students open your listings.')
          else
            ...topProducts.map(
              (item) => _ListingMetricTile(
                name: item['name']?.toString() ?? 'Listing',
                metric: '${_value(item['views'])} views',
                icon: Icons.visibility_outlined,
              ),
            ),
          const SizedBox(height: 20),
          _SectionTitle(title: 'Trending this week'),
          if (trending.isEmpty)
            const _EmptySection(text: 'No weekly activity yet.')
          else
            ...trending.map(
              (item) => _ListingMetricTile(
                name: item['name']?.toString() ?? 'Listing',
                metric: '${_value(item['views_last_7_days'])} views this week',
                icon: Icons.trending_up,
              ),
            ),
          const SizedBox(height: 20),
          _SectionTitle(title: 'Recent reviews'),
          if (reviews.isEmpty)
            const _EmptySection(text: 'Customer reviews will appear here.')
          else
            ...reviews.map((review) => _ReviewTile(review: review)),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.width,
    required this.icon,
    required this.label,
    required this.value,
  });

  final double width;
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: width,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: colors.primary),
              const SizedBox(height: 12),
              Text(
                value,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          title,
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
      );
}

class _ListingMetricTile extends StatelessWidget {
  const _ListingMetricTile({
    required this.name,
    required this.metric,
    required this.icon,
  });

  final String name;
  final String metric;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: Icon(icon),
          title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: Text(metric),
        ),
      );
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review});
  final Map<String, dynamic> review;

  @override
  Widget build(BuildContext context) {
    final rating = double.tryParse(review['rating']?.toString() ?? '') ?? 0;
    final comment = review['comment']?.toString().trim() ?? '';
    return Card(
      child: ListTile(
        leading: const Icon(Icons.star, color: Colors.amber),
        title: Text('${review['user'] ?? 'Customer'} · ${rating.toStringAsFixed(1)}'),
        subtitle: Text(
          comment.isEmpty ? 'No written comment' : comment,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _EmptySection extends StatelessWidget {
  const _EmptySection({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
      );
}

List<Map<String, dynamic>> _mapList(dynamic value) {
  if (value is! List) return [];
  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}

String _value(dynamic value) => value?.toString() ?? '0';

String _rating(dynamic value) {
  final rating = double.tryParse(value?.toString() ?? '') ?? 0;
  return rating.toStringAsFixed(1);
}
