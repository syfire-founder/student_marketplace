import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/services/token_storage.dart';
import '../../../messages/presentation/screens/chat_screen.dart';
import 'business_profile_screen.dart';
import 'report_content_screen.dart';
import '../widgets/business_follow_button.dart';
import '../widgets/business_reviews_section.dart';

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({super.key, required this.productId});

  final int productId;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  late Future<Map<String, dynamic>> _product;

  @override
  void initState() {
    super.initState();
    _product = _loadProduct();
  }

  Future<Map<String, dynamic>> _loadProduct() async {
    final token = await const TokenStorage().getToken();
    final response = await Dio().get(
      '${ApiClient.baseUrl}/products/${widget.productId}/',
      options: Options(
        headers: token == null || token.isEmpty
            ? null
            : {'Authorization': 'Token $token'},
      ),
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<void> _refresh() async {
    final product = _loadProduct();
    setState(() => _product = product);
    await product;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Listing details')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _product,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ProductErrorView(onRetry: _refresh);
          }
          return _ProductDetails(product: snapshot.data!);
        },
      ),
    );
  }
}

class _ProductDetails extends StatefulWidget {
  const _ProductDetails({required this.product});

  final Map<String, dynamic> product;

  @override
  State<_ProductDetails> createState() => _ProductDetailsState();
}

class _ProductDetailsState extends State<_ProductDetails> {
  final PageController _pageController = PageController();
  int _activeImage = 0;
  bool _isStartingConversation = false;
  bool _isFavorite = false;
  bool _isUpdatingFavorite = false;

  @override
  void initState() {
    super.initState();
    _loadFavoriteStatus();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _contactSeller({
    required int sellerId,
    required String sellerName,
  }) async {
    if (_isStartingConversation) return;

    setState(() => _isStartingConversation = true);
    try {
      final token = await const TokenStorage().getToken();
      final response = await Dio().post(
        '${ApiClient.baseUrl}/conversations/',
        data: {
          'participants': [sellerId],
        },
        options: Options(headers: {'Authorization': 'Token $token'}),
      );
      final conversation = Map<String, dynamic>.from(response.data as Map);
      final conversationId = conversation['id'];
      if (conversationId is! int) {
        throw const FormatException('Conversation did not include an id.');
      }
      if (!mounted) return;
      final productImages = _imageUrls(widget.product['images']);
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            conversationId: conversationId,
            sellerName: sellerName,
            productId: int.tryParse(widget.product['id'].toString()),
            productName: _text(widget.product['name'], 'Untitled listing'),
            productImage: productImages.isEmpty ? null : productImages.first,
          ),
        ),
      );
    } on DioException catch (error) {
      if (mounted) {
        final message = error.response?.statusCode == 400
            ? 'You cannot contact the seller of your own listing.'
            : 'Could not start a conversation. Try again.';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } on FormatException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not start a conversation. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isStartingConversation = false);
    }
  }

  Future<void> _toggleFavorite() async {
    if (_isUpdatingFavorite) return;

    setState(() => _isUpdatingFavorite = true);

    try {
      final token = await const TokenStorage().getToken();

      if (token == null || token.isEmpty) {
        throw Exception('You must be logged in to favorite a product.');
      }

      final method = _isFavorite ? 'DELETE' : 'POST';

      await Dio().request(
        '${ApiClient.baseUrl}/products/${widget.product['id']}/favorite/',
        options: Options(
          method: method,
          headers: {'Authorization': 'Token $token'},
        ),
      );

      if (!mounted) return;

      setState(() {
        _isFavorite = !_isFavorite;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isFavorite
                ? 'Added to favorites.'
                : 'Removed from favorites.',
          ),
        ),
      );
    } on DioException catch (error) {
      if (!mounted) return;

      final message = error.response?.data is Map
          ? error.response?.data['detail']?.toString()
          : null;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message ?? 'Could not update favorite. Try again.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUpdatingFavorite = false);
      }
    }
  }

  Future<void> _loadFavoriteStatus() async {
    try {
      final token = await const TokenStorage().getToken();

      if (token == null || token.isEmpty) return;

       final response = await Dio().get(
         '${ApiClient.baseUrl}/products/${widget.product['id']}/favorite/',
         options: Options(
           headers: {'Authorization': 'Token $token'},
       ),
      );

      if (!mounted) return;

      setState(() {
        _isFavorite = response.data['is_favorite'] == true;
      });
    } on DioException {
      // Don't prevent the product page from loading
      // if checking favorite status fails.
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final images = _imageUrls(product['images']);
    final name = _text(product['name'], 'Untitled listing');
    final description = _text(
      product['description'],
      'No description provided.',
    );
    final businessName =
        _nestedText(product, 'business_name', 'business', 'name') ??
        'Campus seller';
    final sellerId = _integer(product['seller_id']);
    final productId = _integer(product['id']);
    final businessValue = product['business'];
    final businessId = _integer(
      businessValue is Map ? businessValue['id'] : businessValue,
    );
    final schoolName = _nestedText(product, 'school_name', 'school', 'name');
    final isService = product['listing_type']?.toString() == 'service';
    final isAvailable = product['is_available'] != false;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ImageGallery(
            images: images,
            pageController: _pageController,
            activeImage: _activeImage,
            onPageChanged: (index) => setState(() => _activeImage = index),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(
                      avatar: Icon(
                        isService
                            ? Icons.handyman_outlined
                            : Icons.shopping_bag_outlined,
                        size: 18,
                      ),
                      label: Text(isService ? 'Service' : 'Product'),
                    ),
                    Chip(
                      avatar: Icon(
                        isAvailable
                            ? Icons.check_circle_outline
                            : Icons.pause_circle_outline,
                        size: 18,
                      ),
                      label: Text(isAvailable ? 'Available' : 'Unavailable'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _isUpdatingFavorite ? null : _toggleFavorite,
                      icon: _isUpdatingFavorite
                      ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        _isFavorite
                            ? Icons.favorite
                            : Icons.favorite_border,
                      ),
                tooltip: _isFavorite
                    ? 'Remove from favorites'
                    : 'Add to favorites',
              ),
            ],
          ),
                const SizedBox(height: 8),
                Text(
                  _price(product['price']),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'Description',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(description, style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 28),
                Text('Seller', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    child: Text(_businessInitials(businessName)),
                  ),
                  title: Text(businessName),
                  subtitle: schoolName == null ? null : Text(schoolName),
                  trailing: businessId == null
                      ? const Icon(Icons.chevron_right)
                      : BusinessFollowButton(
                          businessId: businessId,
                          compact: true,
                        ),
                  onTap: businessId == null
                      ? null
                      : () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => BusinessProfileScreen(
                                businessId: businessId,
                              ),
                            ),
                          ),
                ),
                if (sellerId != null) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isStartingConversation
                          ? null
                          : () => _contactSeller(
                              sellerId: sellerId,
                              sellerName: businessName,
                            ),
                      icon: _isStartingConversation
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.chat_bubble_outline),
                      label: const Text('Contact seller'),
                    ),
                  ),
                ],
                if (businessId != null) ...[
                  const SizedBox(height: 28),
                  BusinessReviewsSection(
                    businessId: businessId,
                    businessName: businessName,
                  ),
                ],
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: productId == null
                      ? null
                      : () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ReportContentScreen(
                        reportType: 'product',
                        contentId: productId,
                        contentName: name,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.flag_outlined),
                  label: const Text('Report this listing'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageGallery extends StatelessWidget {
  const _ImageGallery({
    required this.images,
    required this.pageController,
    required this.activeImage,
    required this.onPageChanged,
  });

  final List<String> images;
  final PageController pageController;
  final int activeImage;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) {
      return AspectRatio(
        aspectRatio: 1.25,
        child: ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: const Center(
            child: Icon(Icons.image_not_supported_outlined, size: 56),
          ),
        ),
      );
    }

    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        AspectRatio(
          aspectRatio: 1.25,
          child: PageView.builder(
            controller: pageController,
            itemCount: images.length,
            onPageChanged: onPageChanged,
            itemBuilder: (context, index) => CachedNetworkImage(
              imageUrl: images[index],
              fit: BoxFit.cover,
              placeholder: (_, _) =>
                  const Center(child: CircularProgressIndicator()),
              errorWidget: (_, _, _) => const Center(
                child: Icon(Icons.broken_image_outlined, size: 52),
              ),
            ),
          ),
        ),
        if (images.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                images.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: index == activeImage ? 18 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ProductErrorView extends StatelessWidget {
  const _ProductErrorView({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 52),
          const SizedBox(height: 16),
          const Text('Could not load this listing'),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    ),
  );
}

List<String> _imageUrls(dynamic value) {
  if (value is! List) return const [];
  return value
      .map((item) {
        if (item is String) return item;
        if (item is Map) return item['image'] ?? item['url'];
        return null;
      })
      .whereType<String>()
      .map(_emulatorMediaUrl)
      .toList();
}

String _emulatorMediaUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri != null && (uri.host == '127.0.0.1' || uri.host == 'localhost')) {
    return uri.replace(host: '10.0.2.2').toString();
  }
  return url;
}

String _text(dynamic value, String fallback) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

String? _nestedText(
  Map<String, dynamic> product,
  String directKey,
  String nestedKey,
  String childKey,
) {
  final direct = product[directKey]?.toString().trim();
  if (direct != null && direct.isNotEmpty) return direct;
  final nested = product[nestedKey];
  if (nested is Map) {
    final value = nested[childKey]?.toString().trim();
    if (value != null && value.isNotEmpty) return value;
  }
  return null;
}

String _price(dynamic value) {
  final price = value?.toString().trim() ?? '';
  return price.isEmpty ? 'Price on request' : '₦$price';
}

int? _integer(dynamic value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '');
}

String _businessInitials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty);
  return parts.take(2).map((part) => part[0].toUpperCase()).join();
}
