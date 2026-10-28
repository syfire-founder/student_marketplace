import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/services/token_storage.dart';
import 'login_screen.dart';
import 'admin_analytics_screen.dart';

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  late Future<List<Map<String, dynamic>>> _reports;
  final Set<int> _processingReportIds = {};
  String _statusFilter = 'pending';

  @override
  void initState() {
    super.initState();
    _reports = _loadReports();
  }

  Future<List<Map<String, dynamic>>> _loadReports() async {
    final token = await const TokenStorage().getToken();
    if (token == null || token.isEmpty) throw Exception('Please sign in again.');
    final response = await Dio().get(
      '${ApiClient.baseUrl}/reports/',
      options: Options(headers: {'Authorization': 'Token $token'}),
    );
    final data = response.data;
    final items = data is Map ? data['results'] as List? ?? const [] : data as List;
    return items
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<void> _refresh() async {
    final request = _loadReports();
    setState(() => _reports = request);
    await request;
  }

  Future<void> _logout() async {
    await const TokenStorage().deleteToken();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Future<void> _setBusinessSuspended(
    Map<String, dynamic> report, {
    required bool suspend,
  }) async {
    final reportId = _asInt(report['id']);
    final business = report['business_details'];
    if (reportId == null || business is! Map) return;
    if (business['is_suspended'] == suspend) return;

    final businessName = business['name']?.toString() ?? 'this business';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          suspend ? 'Suspend business profile?' : 'Unsuspend business profile?',
        ),
        content: Text(
          suspend
              ? '“$businessName” and its listings will be hidden from public browsing. '
                  'The owner’s user account will stay active and they will receive a '
                  'message in their inbox.'
              : '“$businessName” and its listings will be visible in public browsing again. '
                  'The owner will receive an unsuspension message in their inbox.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(suspend ? 'Suspend business' : 'Unsuspend business'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _processingReportIds.add(reportId));
    try {
      final token = await const TokenStorage().getToken();
      if (token == null || token.isEmpty) {
        throw Exception('Please sign in again with the administrator account.');
      }
      final action = suspend ? 'suspend' : 'unsuspend';
      final response = await Dio().post(
        '${ApiClient.baseUrl}/reports/$reportId/$action-business/',
        options: Options(headers: {'Authorization': 'Token $token'}),
      );
      final result = response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : const <String, dynamic>{};
      if (!mounted) return;
      await _refresh();
      if (!mounted) return;
      final messageSent = result['message_sent'] == true;
      final reportersNotified = _asInt(result['reporters_notified']) ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            suspend
                ? reportersNotified > 0
                    ? 'Business profile suspended. Reporting users were notified in their inboxes.'
                    : 'Business profile suspended.'
                : messageSent
                    ? 'Business profile unsuspended. The owner was notified in their inbox.'
                    : result['detail']?.toString() ?? 'Business profile unsuspended.',
          ),
        ),
      );
    } on DioException catch (error) {
      if (!mounted) return;
      final detail = error.response?.data is Map
          ? (error.response!.data as Map)['detail']?.toString()
          : null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(detail ?? 'Could not update this business profile.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) setState(() => _processingReportIds.remove(reportId));
    }
  }

  Future<void> _reviewReport(
    Map<String, dynamic> report, {
    required String outcome,
  }) async {
    final reportId = _asInt(report['id']);
    if (reportId == null || report['review_status'] != 'pending') return;

    final dismiss = outcome == 'dismissed';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dismiss ? 'Dismiss this report?' : 'Mark as reviewed?'),
        content: Text(
          dismiss
              ? 'This report will be closed without taking action.'
              : 'This report will be marked reviewed and removed from the pending queue.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(dismiss ? 'Dismiss report' : 'Mark reviewed'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _processingReportIds.add(reportId));
    try {
      final token = await const TokenStorage().getToken();
      if (token == null || token.isEmpty) {
        throw Exception('Please sign in again with the administrator account.');
      }
      await Dio().post(
        '${ApiClient.baseUrl}/reports/$reportId/review/',
        data: {'outcome': outcome},
        options: Options(headers: {'Authorization': 'Token $token'}),
      );
      if (!mounted) return;
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(dismiss ? 'Report dismissed.' : 'Report marked reviewed.'),
        ),
      );
    } on DioException catch (error) {
      if (!mounted) return;
      final detail = error.response?.data is Map
          ? (error.response!.data as Map)['detail']?.toString()
          : null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(detail ?? 'Could not update this report.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) setState(() => _processingReportIds.remove(reportId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin reports'),
        actions: [
          IconButton(
            tooltip: 'Admin analytics',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AdminAnalyticsScreen()),
            ),
            icon: const Icon(Icons.insights_outlined),
          ),
          IconButton(
            tooltip: 'Refresh reports',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Admin sign out',
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _reports,
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
                    const Text('Could not load reports.'),
                    const SizedBox(height: 12),
                    FilledButton(onPressed: _refresh, child: const Text('Retry')),
                  ],
                ),
              ),
            );
          }
          final allReports = snapshot.data ?? [];
          final reports = allReports.where((report) {
            final status = report['review_status']?.toString() ?? 'pending';
            return switch (_statusFilter) {
              'pending' => status == 'pending',
              'completed' => status != 'pending',
              _ => true,
            };
          }).toList();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'pending', label: Text('Pending')),
                    ButtonSegment(value: 'completed', label: Text('Reviewed')),
                    ButtonSegment(value: 'all', label: Text('All')),
                  ],
                  selected: {_statusFilter},
                  onSelectionChanged: (selection) => setState(
                    () => _statusFilter = selection.first,
                  ),
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refresh,
                  child: reports.isEmpty
                      ? ListView(
                          children: [
                            const SizedBox(height: 120),
                            const Icon(Icons.inbox_outlined, size: 56),
                            const SizedBox(height: 16),
                            Text(
                              allReports.isEmpty
                                  ? 'No reports have been submitted.'
                                  : 'No reports in this section.',
                              textAlign: TextAlign.center,
                            ),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: reports.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final report = reports[index];
                            final reportId = _asInt(report['id']);
                            return _ReportCard(
                              report: report,
                              isSuspending: reportId != null &&
                                  _processingReportIds.contains(reportId),
                              onToggleBusinessSuspension: (suspend) =>
                                  _setBusinessSuspended(report, suspend: suspend),
                              onReview: (outcome) =>
                                  _reviewReport(report, outcome: outcome),
                            );
                          },
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.report,
    required this.isSuspending,
    required this.onToggleBusinessSuspension,
    required this.onReview,
  });

  final Map<String, dynamic> report;
  final bool isSuspending;
  final ValueChanged<bool> onToggleBusinessSuspension;
  final ValueChanged<String> onReview;

  @override
  Widget build(BuildContext context) {
    final isProduct = report['report_type'] == 'product';
    final target = isProduct
        ? report['product_name']?.toString() ?? 'Product #${report['product']}'
        : report['business_name']?.toString() ?? 'Business #${report['business']}';
    final date = DateTime.tryParse(report['created_at']?.toString() ?? '');
    final productDetails = report['product_details'] is Map
        ? Map<String, dynamic>.from(report['product_details'] as Map)
        : null;
    final businessDetails = report['business_details'] is Map
        ? Map<String, dynamic>.from(report['business_details'] as Map)
        : null;
    final isSuspended = businessDetails?['is_suspended'] == true;
    final reviewStatus = report['review_status']?.toString() ?? 'pending';
    final productImages = productDetails?['images'];
    final firstImage = productImages is List && productImages.isNotEmpty
        ? productImages.first
        : null;
    final imageUrl = firstImage is Map
        ? firstImage['image']?.toString()
        : firstImage?.toString();
    return Card(
      child: ExpansionTile(
        leading: Icon(isProduct ? Icons.inventory_2_outlined : Icons.storefront_outlined),
        title: Text(target),
        subtitle: Text(
          '${isProduct ? 'Product report' : 'Business report'} · ${report['reporter'] ?? 'Unknown user'}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Chip(
                label: Text(_reviewStatusLabel(reviewStatus)),
              ),
            ),
          ),
          if (productDetails != null) ...[
            if (imageUrl != null && imageUrl.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  imageUrl,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
              const SizedBox(height: 12),
            ],
            _AdminDetailLabel(
              label: 'Reported listing',
              value: productDetails['name']?.toString() ?? target,
            ),
            _AdminDetailLabel(
              label: 'Type',
              value: productDetails['listing_type']?.toString() ?? 'Listing',
            ),
            _AdminDetailLabel(
              label: 'Description',
              value: productDetails['description']?.toString().trim().isNotEmpty == true
                  ? productDetails['description'].toString()
                  : 'No description provided.',
            ),
            _AdminDetailLabel(
              label: 'Price',
              value: productDetails['price'] == null
                  ? 'Price on request'
                  : '₦${productDetails['price']}',
            ),
            const Divider(height: 24),
          ],
          if (businessDetails != null) ...[
            _AdminDetailLabel(
              label: 'Business',
              value: businessDetails['name']?.toString() ?? 'Unknown business',
            ),
            _AdminDetailLabel(
              label: 'Owner',
              value: businessDetails['owner']?.toString() ?? 'Unknown owner',
            ),
            _AdminDetailLabel(
              label: 'School',
              value: businessDetails['school']?.toString() ?? 'Not provided',
            ),
            _AdminDetailLabel(
              label: 'Description',
              value: businessDetails['description']?.toString().trim().isNotEmpty == true
                  ? businessDetails['description'].toString()
                  : 'No description provided.',
            ),
            if (isSuspended)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Chip(
                  avatar: Icon(Icons.block, size: 18),
                  label: Text('Business profile suspended'),
                ),
              ),
            if (isSuspended || reviewStatus == 'pending')
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: isSuspending
                        ? null
                        : () => onToggleBusinessSuspension(!isSuspended),
                    icon: isSuspending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            isSuspended
                                ? Icons.check_circle_outline
                                : Icons.block_outlined,
                          ),
                    label: Text(
                      isSuspending
                          ? (isSuspended ? 'Unsuspending…' : 'Suspending…')
                          : (isSuspended
                              ? 'Unsuspend business profile'
                              : 'Suspend business profile'),
                    ),
                  ),
                ),
              ),
            const Divider(height: 24),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Reason',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(report['reason']?.toString() ?? ''),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              date == null ? 'Report #${report['id']}' : 'Submitted ${date.toLocal()}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          if (reviewStatus == 'pending') ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: isSuspending ? null : () => onReview('reviewed'),
                  icon: const Icon(Icons.done),
                  label: const Text('Mark reviewed'),
                ),
                TextButton.icon(
                  onPressed: isSuspending ? null : () => onReview('dismissed'),
                  icon: const Icon(Icons.remove_circle_outline),
                  label: const Text('Dismiss report'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _AdminDetailLabel extends StatelessWidget {
  const _AdminDetailLabel({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 2),
          Text(value),
        ],
      ),
    );
  }
}

int? _asInt(dynamic value) =>
    value is int ? value : int.tryParse(value?.toString() ?? '');

String _reviewStatusLabel(String status) => switch (status) {
      'action_taken' => 'Action taken',
      'reviewed' => 'Reviewed',
      'dismissed' => 'Dismissed',
      _ => 'Pending review',
    };
