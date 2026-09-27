import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/services/token_storage.dart';
import '../../providers/auth_state_provider.dart';
import 'login_screen.dart';
import 'create_listing_screen.dart';
import '../../../messages/presentation/screens/inbox_screen.dart';
import '../../../notifications/presentation/screens/notifications_screen.dart';
import '../../../products/presentation/screens/product_detail_screen.dart';

class AuthenticatedScreen extends ConsumerStatefulWidget {
  const AuthenticatedScreen({super.key});

  @override
  ConsumerState<AuthenticatedScreen> createState() =>
      _AuthenticatedScreenState();
}

class _AuthenticatedScreenState extends ConsumerState<AuthenticatedScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: const [
          _HomeTab(),
          _InboxTab(),
          _SellTab(),
          _ProfileTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (value) {
          setState(() {
            _tab = value;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.forum_outlined),
            selectedIcon: Icon(Icons.forum),
            label: 'Inbox',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_box_outlined),
            selectedIcon: Icon(Icons.add_box),
            label: 'Sell',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _InboxTab extends StatelessWidget {
  const _InboxTab();

  @override
  Widget build(BuildContext context) {
    return const InboxScreen();
  }
}

class _HomeTab extends StatefulWidget {
  const _HomeTab();

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  late Future<Map<String, dynamic>> _feed;

  final TextEditingController _searchController = TextEditingController();

  bool _isSearching = false;
  bool _searchLoading = false;

  String? _searchError;

  List<Map<String, dynamic>> _searchProducts = [];
  List<Map<String, dynamic>> _searchBusinesses = [];

  String _listingType = 'all';

  @override
  void initState() {
    super.initState();
    _feed = _loadFeed();

    _searchController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<String> _getToken() async {
    final token = await const TokenStorage().getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Session expired. Please sign in again.');
    }

    return token;
  }

  Future<Map<String, dynamic>> _loadFeed() async {
    final token = await _getToken();

    final response = await Dio().get(
      '${ApiClient.baseUrl}/feed/',
      options: Options(
        headers: {
          'Authorization': 'Token $token',
        },
      ),
    );

    return Map<String, dynamic>.from(
      response.data as Map,
    );
  }

  Future<void> _refresh() async {
    final feed = _loadFeed();

    setState(() {
      _feed = feed;
    });

    await feed;
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();

    if (query.isEmpty && _listingType == 'all') {
      setState(() {
        _isSearching = false;
        _searchError = null;
        _searchProducts = [];
        _searchBusinesses = [];
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchLoading = true;
      _searchError = null;
    });

    try {
      final token = await _getToken();

      final queryParameters = <String, dynamic>{};

      if (query.isNotEmpty) {
        queryParameters['q'] = query;
      }

      if (_listingType != 'all') {
        queryParameters['listing_type'] = _listingType;
      }

      final response = await Dio().get(
        '${ApiClient.baseUrl}/search/',
        queryParameters: queryParameters,
        options: Options(
          headers: {
            'Authorization': 'Token $token',
          },
        ),
      );

      final data = Map<String, dynamic>.from(
        response.data as Map,
      );

      final products = _parseList(data['products']);
      final businesses = _parseList(data['businesses']);

      if (!mounted) {
        return;
      }

      setState(() {
        _searchProducts = products;
        _searchBusinesses = businesses;
        _searchLoading = false;
        _searchError = null;
      });
    } on DioException catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _searchLoading = false;
        _searchError =
            e.response?.data?['detail']?.toString() ??
            'Could not complete the search.';
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _searchLoading = false;
        _searchError = 'Could not complete the search.';
      });
    }
  }

  List<Map<String, dynamic>> _parseList(dynamic value) {
    if (value is! List) {
      return [];
    }

    return value
        .whereType<Map>()
        .map(
          (item) => Map<String, dynamic>.from(item),
        )
        .toList();
  }

  void _clearSearch() {
    _searchController.clear();

    setState(() {
      _isSearching = false;
      _searchLoading = false;
      _searchError = null;
      _searchProducts = [];
      _searchBusinesses = [];
      _listingType = 'all';
    });
  }

  void _changeListingType(String value) {
    setState(() {
      _listingType = value;
    });

    if (_searchController.text.trim().isNotEmpty) {
      _performSearch();
    } else if (value != 'all') {
      _performSearch();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: _buildHeader(),
          ),
          Expanded(
            child: _isSearching
                ? _buildSearchResults()
                : _buildFeed(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Discover',
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.notifications_outlined),
              tooltip: 'Notifications',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const NotificationsScreen(),
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Align(
          alignment: Alignment.centerLeft,
          child: Text('Listings from your campus'),
        ),
        const SizedBox(height: 16),

        _buildSearchBar(),
        const SizedBox(height: 12),
        _buildListingTypeFilters(),
      ],
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => _performSearch(),
      decoration: InputDecoration(
        hintText: 'Search products, services, or businesses',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _searchController.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.clear),
                tooltip: 'Clear',
                onPressed: _clearSearch,
              ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  Widget _buildListingTypeFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ChoiceChip(
            label: const Text('All'),
            selected: _listingType == 'all',
            onSelected: (_) {
              _changeListingType('all');
            },
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: const Text('Products'),
            selected: _listingType == 'product',
            onSelected: (_) {
              _changeListingType('product');
            },
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: const Text('Services'),
            selected: _listingType == 'service',
            onSelected: (_) {
              _changeListingType('service');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFeed() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _feed,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return _ErrorView(
            message: snapshot.error.toString(),
            onRetry: _refresh,
          );
        }

        final data = snapshot.data!;

        final arrivals = _parseList(
          data['new_arrivals'],
        );

        final recommended = _parseList(
          data['recommended'],
        );

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              20,
              20,
              20,
              100,
            ),
            children: [
              if (arrivals.isEmpty && recommended.isEmpty)
                const _EmptyView()
              else ...[
                if (arrivals.isNotEmpty)
                  _Section(
                    title: 'New arrivals',
                    listings: arrivals,
                  ),
                if (recommended.isNotEmpty)
                  _Section(
                    title: 'Recommended for you',
                    listings: recommended,
                  ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchResults() {
    if (_searchLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_searchError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.search_off_outlined,
                size: 52,
              ),
              const SizedBox(height: 16),
              Text(
                _searchError!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _performSearch,
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_searchProducts.isEmpty && _searchBusinesses.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(28),
        children: const [
          SizedBox(height: 70),
          Icon(
            Icons.search_off_outlined,
            size: 56,
          ),
          SizedBox(height: 16),
          Text(
            'No results found',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Try a different product, service, or business name.',
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        20,
        20,
        20,
        100,
      ),
      children: [
        if (_searchProducts.isNotEmpty) ...[
          Text(
            'Listings',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 10),
          ..._searchProducts.map(
            (listing) => _ListingTile(
              listing: listing,
            ),
          ),
        ],
        if (_searchBusinesses.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            'Businesses',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 10),
          ..._searchBusinesses.map(
            (business) => _BusinessTile(
              business: business,
            ),
          ),
        ],
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.listings,
  });

  final String title;
  final List<Map<String, dynamic>> listings;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 10),
        ...listings.map(
          (listing) => _ListingTile(
            listing: listing,
          ),
        ),
        const SizedBox(height: 22),
      ],
    );
  }
}

class _ListingTile extends StatelessWidget {
  const _ListingTile({
    required this.listing,
  });

  final Map<String, dynamic> listing;

  @override
  Widget build(BuildContext context) {
    final price = listing['price'] == null
        ? 'Price on request'
        : '₦${listing['price']}';

    final isService = listing['listing_type'] == 'service';

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(
            isService
                ? Icons.handyman_outlined
                : Icons.shopping_bag_outlined,
          ),
        ),
        title: Text(
          listing['name']?.toString() ??
              'Untitled listing',
        ),
        subtitle: Text(
          '${listing['business_name'] ?? 'Campus seller'} · $price',
        ),
        trailing: const Icon(
          Icons.chevron_right,
        ),
        onTap: () {
          final id = listing['id'];

          final productId = id is int
              ? id
              : int.tryParse(
                  id?.toString() ?? '',
                );

          if (productId == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'This listing cannot be opened yet.',
                ),
              ),
            );
            return;
          }

          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ProductDetailScreen(
                productId: productId,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BusinessTile extends StatelessWidget {
  const _BusinessTile({
    required this.business,
  });

  final Map<String, dynamic> business;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(
          child: Icon(Icons.storefront_outlined),
        ),
        title: Text(
          business['name']?.toString() ??
              'Unnamed business',
        ),
        subtitle: Text(
          business['description']?.toString() ??
              'Campus business',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(
          Icons.chevron_right,
        ),
      ),
    );
  }
}

class _ProfileTab extends ConsumerWidget {
  const _ProfileTab();

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              'Profile',
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 24),
            const ListTile(
              leading: CircleAvatar(
                child: Icon(Icons.person),
              ),
              title: Text(
                'Your SWIX account',
              ),
              subtitle: Text(
                'Campus marketplace member',
              ),
            ),
            const Spacer(),
            FilledButton.tonalIcon(
              onPressed: () async {
                await ref
                    .read(
                      authControllerProvider
                          .notifier,
                    )
                    .logout();

                if (context.mounted) {
                  Navigator.of(context)
                      .pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (_) =>
                          const LoginScreen(),
                    ),
                    (_) => false,
                  );
                }
              },
              icon: const Icon(Icons.logout),
              label: const Text('Log out'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SellTab extends StatelessWidget {
  const _SellTab();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              'Sell',
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Put your products and services in front of students on your campus.',
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton.icon(
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          const CreateListingScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.add),
                label: const Text(
                  'Create listing',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 80),
      child: Column(
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 52,
          ),
          SizedBox(height: 12),
          Text('No listings yet'),
          SizedBox(height: 6),
          Text(
            'Pull down to refresh after listings are added.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.message,
    required this.onRetry,
  });

  final String message;
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
              'Could not load listings',
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              child: const Text(
                'Try again',
              ),
            ),
          ],
        ),
      ),
    );
  }
}