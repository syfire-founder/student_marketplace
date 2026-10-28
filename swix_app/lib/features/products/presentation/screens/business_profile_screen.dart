import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/services/token_storage.dart';
import '../../../auth/presentation/screens/create_listing_screen.dart';
import '../../../auth/presentation/screens/edit_listing_screen.dart';
import 'edit_business_profile_screen.dart';
import 'product_detail_screen.dart';
import 'report_content_screen.dart';
import '../widgets/business_follow_button.dart';
import '../widgets/business_reviews_section.dart';

class BusinessProfileScreen extends StatefulWidget {
  const BusinessProfileScreen({super.key, required this.businessId});

  final int businessId;

  @override
  State<BusinessProfileScreen> createState() => _BusinessProfileScreenState();
}

class _BusinessProfileScreenState extends State<BusinessProfileScreen> {
  late Future<Map<String, dynamic>> _business;

  @override
  void initState() {
    super.initState();
    _business = _loadBusiness();
  }

  Future<Map<String, dynamic>> _loadBusiness() async {
    final token = await const TokenStorage().getToken();
    final response = await Dio().get(
      '${ApiClient.baseUrl}/businessprofiles/${widget.businessId}/',
      options: Options(
        headers: token == null || token.isEmpty
            ? null
            : {'Authorization': 'Token $token'},
      ),
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<void> _retry() async {
    final request = _loadBusiness();
    setState(() => _business = request);
    await request;
  }

  Future<void> _editBusiness(Map<String, dynamic> business) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EditBusinessProfileScreen(business: business),
      ),
    );
    if (changed == true && mounted) {
      setState(() => _business = _loadBusiness());
    }
  }

  Future<void> _addListing() async {
    final created = await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CreateListingScreen()),
    );
    if (created != null && mounted) {
      setState(() => _business = _loadBusiness());
    }
  }

  void _refreshBusiness() {
    setState(() => _business = _loadBusiness());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Business profile')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _business,
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
                    const Text('Could not load this business profile.'),
                    const SizedBox(height: 12),
                    FilledButton(onPressed: _retry, child: const Text('Retry')),
                  ],
                ),
              ),
            );
          }
          return _BusinessProfileContent(
            business: snapshot.data!,
            onEditBusiness: () => _editBusiness(snapshot.data!),
            onAddListing: _addListing,
            onRefresh: _refreshBusiness,
          );
        },
      ),
    );
  }
}

class _BusinessProfileContent extends StatelessWidget {
  const _BusinessProfileContent({
    required this.business,
    required this.onEditBusiness,
    required this.onAddListing,
    required this.onRefresh,
  });

  final Map<String, dynamic> business;
  final VoidCallback onEditBusiness;
  final VoidCallback onAddListing;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final name = business['name']?.toString().trim().isNotEmpty == true
        ? business['name'].toString()
        : 'Campus business';
    final description = business['description']?.toString().trim() ?? '';
    final businessId = _toInt(business['id']);
    final listings = (business['products'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      children: [
        Center(
          child: CircleAvatar(
            radius: 46,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: _logoUrl(business['logo']) == null
                ? Text(
                    _initials(name),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                  )
                : ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: _logoUrl(business['logo'])!,
                      width: 92,
                      height: 92,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Center(
                        child: Text(_initials(name)),
                      ),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          name,
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        if (business['school_name']?.toString().isNotEmpty == true) ...[
          const SizedBox(height: 4),
          Text(
            business['school_name'].toString(),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
        if (business['is_owner'] == true) ...[
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onEditBusiness,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Edit business profile'),
          ),
        ],
        if (business['is_owner'] != true) ...[
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (businessId != null)
                BusinessFollowButton(businessId: businessId),
              TextButton.icon(
                onPressed: () {
                  if (businessId == null) return;
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ReportContentScreen(
                        reportType: 'business',
                        contentId: businessId,
                        contentName: name,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.flag_outlined),
                label: const Text('Report this business'),
              ),
            ],
          ),
        ],
        const SizedBox(height: 24),
        Text('About', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          description.isEmpty ? 'No description provided yet.' : description,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 28),
        Text('Products and services',
            style: Theme.of(context).textTheme.titleLarge),
        if (business['is_owner'] == true) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onAddListing,
              icon: const Icon(Icons.add),
              label: const Text('Add product or service'),
            ),
          ),
        ],
        const SizedBox(height: 12),
        if (listings.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text('This business has no listings yet.'),
          )
        else
          ...listings.map(
            (listing) => _BusinessListingCard(
              listing: listing,
              canEdit: business['is_owner'] == true,
              onEdit: () async {
                final updated = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => EditListingScreen(listing: listing),
                  ),
                );
                if (updated == true) onRefresh();
              },
            ),
          ),
        if (businessId != null) ...[
          const SizedBox(height: 16),
          BusinessReviewsSection(
            businessId: businessId,
            businessName: name,
            canReview: business['is_owner'] != true,
          ),
        ],
      ],
    );
  }
}

class _BusinessListingCard extends StatelessWidget {
  const _BusinessListingCard({
    required this.listing,
    required this.canEdit,
    required this.onEdit,
  });

  final Map<String, dynamic> listing;
  final bool canEdit;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final isService = listing['listing_type']?.toString() == 'service';
    final images = listing['images'];
    final image = images is List && images.isNotEmpty
        ? _resolveImageUrl(images.first)
        : null;
    final id = _toInt(listing['id']);
    final price = listing['price'] == null
        ? 'Price on request'
        : '₦${listing['price']}';

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: id == null
            ? null
            : () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ProductDetailScreen(productId: id),
                  ),
                ),
        child: AspectRatio(
          aspectRatio: 1.65,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (image != null)
                CachedNetworkImage(
                  imageUrl: image,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => ColoredBox(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    child: Icon(
                      isService
                          ? Icons.handyman_outlined
                          : Icons.shopping_bag_outlined,
                      size: 48,
                    ),
                  ),
                )
              else
                ColoredBox(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: Icon(
                    isService
                        ? Icons.handyman_outlined
                        : Icons.shopping_bag_outlined,
                    size: 48,
                  ),
                ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xB8000000)],
                    stops: [0.3, 1],
                  ),
                ),
              ),
              if (canEdit)
                Positioned(
                  top: 12,
                  right: 12,
                  child: Material(
                    color: Colors.white,
                    shape: const CircleBorder(),
                    child: IconButton(
                      tooltip: 'Edit listing',
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined),
                    ),
                  ),
                ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      listing['name']?.toString() ?? 'Untitled listing',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            isService ? 'Service' : 'Product',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        Text(
                          price,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty);
  return parts.take(2).map((part) => part[0].toUpperCase()).join();
}

int? _toInt(dynamic value) =>
    value is int ? value : int.tryParse(value?.toString() ?? '');

String? _resolveImageUrl(dynamic value) {
  final raw = value is Map ? value['image']?.toString() : value?.toString();
  if (raw == null || raw.trim().isEmpty) return null;
  final uri = Uri.tryParse(raw);
  if (uri == null) return null;
  return uri.hasScheme ? raw : Uri.parse(ApiClient.baseUrl).resolve(raw).toString();
}

String? _logoUrl(dynamic value) {
  final raw = value?.toString();
  if (raw == null || raw.trim().isEmpty) return null;
  final uri = Uri.tryParse(raw);
  if (uri == null) return null;
  return uri.hasScheme ? raw : Uri.parse(ApiClient.baseUrl).resolve(raw).toString();
}
