import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/services/token_storage.dart';
import 'product_detail_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  late Future<List<Map<String, dynamic>>> _favorites;

  @override
  void initState() {
    super.initState();
    _favorites = _loadFavorites();
  }

  Future<List<Map<String, dynamic>>> _loadFavorites() async {
    final token = await const TokenStorage().getToken();

    if (token == null || token.isEmpty) {
      throw Exception(
        'Session expired. Please sign in again.',
      );
    }

    final response = await Dio().get(
      '${ApiClient.baseUrl}/product-favorites/',
      options: Options(
        headers: {
          'Authorization': 'Token $token',
        },
      ),
    );

    final data = response.data;

    if (data is List) {
      return data
          .whereType<Map>()
          .map(
            (item) => Map<String, dynamic>.from(item),
          )
          .toList();
    }

    if (data is Map && data['results'] is List) {
      return (data['results'] as List)
          .whereType<Map>()
          .map(
            (item) => Map<String, dynamic>.from(item),
          )
          .toList();
    }

    return [];
  }

  Future<void> _refresh() async {
    final favorites = _loadFavorites();

    setState(() {
      _favorites = favorites;
    });

    await favorites;
  }

  Future<void> _openFavorite(
    Map<String, dynamic> favorite,
  ) async {
    final product = favorite['product'];

    final productId = product is Map
        ? _integer(product['id'])
        : _integer(product);

    if (productId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This favorite cannot be opened.',
          ),
        ),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(
          productId: productId,
        ),
      ),
    );

    if (mounted) {
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Favorites'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _favorites,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return _FavoritesErrorView(
              onRetry: _refresh,
            );
          }

          final favorites = snapshot.data ?? [];

          if (favorites.isEmpty) {
            return const _EmptyFavoritesView();
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(
                16,
                16,
                16,
                32,
              ),
              itemCount: favorites.length,
              itemBuilder: (context, index) {
                final favorite = favorites[index];

                return _FavoriteTile(
                  favorite: favorite,
                  onTap: () => _openFavorite(favorite),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _FavoriteTile extends StatelessWidget {
  const _FavoriteTile({
    required this.favorite,
    required this.onTap,
  });

  final Map<String, dynamic> favorite;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final product = favorite['product'];

    final productMap = product is Map
        ? Map<String, dynamic>.from(product)
        : null;

    final name = productMap?['name']?.toString() ??
        'Saved listing';

    final listingType =
        productMap?['listing_type']?.toString();

    final price = productMap?['price'];

    final isService = listingType == 'service';

    final priceText = price == null
        ? 'Price on request'
        : '₦$price';

    final imageList = productMap?['images'];

    String? imageUrl;

    if (imageList is List && imageList.isNotEmpty) {
      final firstImage = imageList.first;

      if (firstImage is Map) {
        imageUrl = firstImage['image']?.toString();
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: imageUrl != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  imageUrl,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  errorBuilder: (
                    context,
                    error,
                    stackTrace,
                  ) {
                    return const CircleAvatar(
                      child: Icon(
                        Icons.image_not_supported_outlined,
                      ),
                    );
                  },
                ),
              )
            : CircleAvatar(
                child: Icon(
                  isService
                      ? Icons.handyman_outlined
                      : Icons.shopping_bag_outlined,
                ),
              ),
        title: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${isService ? 'Service' : 'Product'} · $priceText',
        ),
        trailing: const Icon(
          Icons.chevron_right,
        ),
        onTap: onTap,
      ),
    );
  }
}

class _EmptyFavoritesView extends StatelessWidget {
  const _EmptyFavoritesView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.favorite_border,
              size: 64,
              color: Theme.of(context)
                  .colorScheme
                  .primary,
            ),
            const SizedBox(height: 16),
            Text(
              'No favorites yet',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Save products and services you want to come back to.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _FavoritesErrorView extends StatelessWidget {
  const _FavoritesErrorView({
    required this.onRetry,
  });

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 52,
            ),
            const SizedBox(height: 16),
            const Text(
              'Could not load favorites',
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

int? _integer(dynamic value) {
  if (value is int) {
    return value;
  }

  return int.tryParse(
    value?.toString() ?? '',
  );
}