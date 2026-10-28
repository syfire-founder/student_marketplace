import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/services/token_storage.dart';
import '../../providers/auth_state_provider.dart';
import 'login_screen.dart';
import 'create_business_screen.dart';
import 'create_listing_screen.dart';
import '../../../messages/presentation/screens/inbox_screen.dart';
import '../../../notifications/presentation/screens/notifications_screen.dart';
import '../../../products/presentation/screens/product_detail_screen.dart';
import '../../../products/presentation/screens/favorites_screen.dart';
import '../../../products/presentation/screens/business_profile_screen.dart';
import '../../../products/presentation/screens/business_analytics_screen.dart';

class AuthenticatedScreen extends ConsumerStatefulWidget {
  const AuthenticatedScreen({super.key});

  @override
  ConsumerState<AuthenticatedScreen> createState() =>
      _AuthenticatedScreenState();
}

class _AuthenticatedScreenState extends ConsumerState<AuthenticatedScreen> {
  int _tab = 0;
  bool _hasUnreadNotifications = false;
  bool _hasUnreadMessages = false;

  @override
  void initState() {
    super.initState();
    _refreshUnreadCounts();
  }

  Future<void> _refreshUnreadCounts() async {
    try {
      final token = await const TokenStorage().getToken();
      if (token == null || token.isEmpty) return;
      final options = Options(headers: {'Authorization': 'Token $token'});
      final responses = await Future.wait([
        Dio().get('${ApiClient.baseUrl}/notifications/unread-count/', options: options),
        Dio().get('${ApiClient.baseUrl}/conversations/unread-count/', options: options),
      ]);
      final notificationData = responses[0].data;
      final messageData = responses[1].data;
      if (!mounted) return;
      setState(() {
        _hasUnreadNotifications = _hasUnread(notificationData);
        _hasUnreadMessages = _hasUnread(messageData);
      });
    } catch (_) {
      // Badge count failures should not interrupt normal app use.
    }
  }

  bool _hasUnread(dynamic data) {
    if (data is! Map) return false;
    final count = int.tryParse(data['unread_count']?.toString() ?? '') ?? 0;
    return count > 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          _HomeTab(
            hasUnreadNotifications: _hasUnreadNotifications,
            onNotificationsOpened: _refreshUnreadCounts,
          ),
          _InboxTab(onUnreadMessagesChanged: _refreshUnreadCounts),
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
          _refreshUnreadCounts();
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: _NotificationDotIcon(
              icon: Icons.forum_outlined,
              showDot: _hasUnreadMessages,
            ),
            selectedIcon: _NotificationDotIcon(
              icon: Icons.forum,
              showDot: _hasUnreadMessages,
            ),
            label: 'Inbox',
          ),
          NavigationDestination(
            icon: const Icon(Icons.add_box_outlined),
            selectedIcon: const Icon(Icons.add_box),
            label: 'Sell',
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _InboxTab extends StatelessWidget {
  const _InboxTab({required this.onUnreadMessagesChanged});

  final VoidCallback onUnreadMessagesChanged;

  @override
  Widget build(BuildContext context) {
    return InboxScreen(onUnreadMessagesChanged: onUnreadMessagesChanged);
  }
}

class _NotificationDotIcon extends StatelessWidget {
  const _NotificationDotIcon({required this.icon, required this.showDot});

  final IconData icon;
  final bool showDot;

  @override
  Widget build(BuildContext context) => Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(icon),
          if (showDot)
            Positioned(
              top: -1,
              right: -1,
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.surface,
                    width: 1.5,
                  ),
                ),
              ),
            ),
        ],
      );
}

class _HomeTab extends StatefulWidget {
  const _HomeTab({
    required this.hasUnreadNotifications,
    required this.onNotificationsOpened,
  });

  final bool hasUnreadNotifications;
  final VoidCallback onNotificationsOpened;

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
  String _feedMode = 'top';

  @override
  void initState() {
    super.initState();
    _feed = _loadFeed();
    _recordAppVisit();

    _searchController.addListener(() {
      setState(() {});
    });
  }

  Future<void> _recordAppVisit() async {
    try {
      final token = await _getToken();
      await Dio().post(
        '${ApiClient.baseUrl}/app-visits/',
        options: Options(headers: {'Authorization': 'Token $token'}),
      );
    } catch (_) {
      // Visit tracking should not interrupt opening the home screen.
    }
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
    final feed = _feedMode == 'recents' ? _loadRecentFeed() : _loadFeed();

    setState(() {
      _feed = feed;
    });

    await feed;
  }

  Future<Map<String, dynamic>> _loadRecentFeed() async {
    final token = await _getToken();
    final options = Options(headers: {'Authorization': 'Token $token'});
    final responses = await Future.wait([
      Dio().get('${ApiClient.baseUrl}/recently-viewed/', options: options),
      Dio().get('${ApiClient.baseUrl}/recently-viewed-businesses/', options: options),
    ]);
    return {
      'products': _parseList(responses[0].data),
      'businesses': _parseList(responses[1].data),
    };
  }

  void _changeFeedMode(String value) {
    setState(() => _feedMode = value);
    if (_isSearching) {
      if (value == 'product' || value == 'service') {
        setState(() => _listingType = value);
        _performSearch();
        return;
      }
      _searchController.clear();
      setState(() {
        _isSearching = false;
        _searchProducts = [];
        _searchBusinesses = [];
        _listingType = 'all';
      });
    }
    if (value == 'recents') {
      setState(() => _feed = _loadRecentFeed());
    } else {
      setState(() => _feed = _loadFeed());
    }
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
              icon: _NotificationDotIcon(
                icon: Icons.notifications_outlined,
                showDot: widget.hasUnreadNotifications,
              ),
              tooltip: 'Notifications',
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const NotificationsScreen(),
                  ),
                );
                widget.onNotificationsOpened();
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
    Widget chip(String label, String value) => ChoiceChip(
          label: Text(label),
          selected: _feedMode == value,
          onSelected: (_) => _changeFeedMode(value),
        );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          chip('Top', 'top'),
          const SizedBox(width: 8),
          chip('New arrivals', 'new'),
          const SizedBox(width: 8),
          chip('Recents', 'recents'),
          const SizedBox(width: 8),
          chip('Products', 'product'),
          const SizedBox(width: 8),
          chip('Services', 'service'),
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

        final arrivals = _parseList(data['new_arrivals']);
        final popular = _parseList(data['popular']);
        final allListings = _parseList(data['all_listings']);
        final recentProducts = _parseList(data['products']);
        final recentBusinesses = _parseList(data['businesses']);
        final recentItems = <Map<String, dynamic>>[
          ...recentProducts.map((visit) => {
                'kind': 'product',
                'viewed_at': visit['viewed_at'],
                'item': _mapValue(visit['product']),
              }),
          ...recentBusinesses.map((visit) => {
                'kind': 'business',
                'viewed_at': visit['viewed_at'],
                'item': _mapValue(visit['business']),
              }),
        ]..sort((a, b) {
            final first = DateTime.tryParse(a['viewed_at']?.toString() ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0);
            final second = DateTime.tryParse(b['viewed_at']?.toString() ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0);
            return second.compareTo(first);
          });
        final listings = switch (_feedMode) {
          'new' => arrivals,
          'recents' => <Map<String, dynamic>>[],
          _ => popular,
        };
        final visibleListings = (_feedMode == 'product' || _feedMode == 'service')
            ? allListings.where((item) => item['listing_type'] == _feedMode).toList()
            : listings;
        final title = switch (_feedMode) {
          'new' => 'New arrivals',
          'recents' => 'Recently viewed',
          'product' => 'Products',
          'service' => 'Services',
          _ => 'Top',
        };

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
              if (_feedMode == 'recents'
                  ? recentItems.isEmpty
                  : visibleListings.isEmpty)
                _feedMode == 'recents'
                    ? const _EmptyView(
                        message: 'Nothing viewed recently',
                        helper: 'Products and businesses you open will appear here.',
                      )
                    : const _EmptyView()
              else ...[
                if (_feedMode == 'recents')
                  ...recentItems.map((recent) {
                    final item = _mapValue(recent['item']);
                    if (item == null) return const SizedBox.shrink();
                    return recent['kind'] == 'business'
                        ? _BusinessTile(business: item)
                        : _ListingTile(listing: item);
                  })
                else if (visibleListings.isNotEmpty)
                  _Section(title: title, listings: visibleListings),
              ],
            ],
          ),
        );
      },
    );
  }

  Map<String, dynamic>? _mapValue(dynamic value) => value is Map
      ? Map<String, dynamic>.from(value)
      : null;

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
    final imageUrl = _listingImageUrl(listing);
    final colorScheme = Theme.of(context).colorScheme;
    final titleColor = Colors.white;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openListing(context),
        child: AspectRatio(
          aspectRatio: 1.65,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (imageUrl != null)
                CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => ColoredBox(
                    color: colorScheme.primaryContainer,
                    child: Icon(
                      isService
                          ? Icons.handyman_outlined
                          : Icons.shopping_bag_outlined,
                      size: 44,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                  errorWidget: (context, url, error) => ColoredBox(
                    color: colorScheme.primaryContainer,
                    child: Icon(
                      isService
                          ? Icons.handyman_outlined
                          : Icons.shopping_bag_outlined,
                      size: 44,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                )
              else
                ColoredBox(
                  color: colorScheme.primary,
                  child: Icon(
                    isService
                        ? Icons.handyman_outlined
                        : Icons.shopping_bag_outlined,
                    size: 52,
                    color: colorScheme.onPrimary,
                  ),
                ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.72),
                    ],
                    stops: const [0.3, 1],
                  ),
                ),
              ),
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surface.withOpacity(0.92),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isService
                            ? Icons.handyman_outlined
                            : Icons.shopping_bag_outlined,
                        size: 14,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        isService ? 'SERVICE' : 'PRODUCT',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                              letterSpacing: 0.5,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                right: 12,
                top: 12,
                child: CircleAvatar(
                  radius: 17,
                  backgroundColor: Colors.black.withOpacity(0.38),
                  child: const Icon(
                    Icons.arrow_forward,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      listing['name']?.toString() ?? 'Untitled listing',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: titleColor,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            listing['business_name']?.toString() ??
                                'Campus seller',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.white.withOpacity(0.9),
                                ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          price,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                color: titleColor,
                                fontWeight: FontWeight.w700,
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

  void _openListing(BuildContext context) {
    final id = listing['id'];
    final productId = id is int ? id : int.tryParse(id?.toString() ?? '');

    if (productId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This listing cannot be opened yet.'),
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(productId: productId),
      ),
    );
  }
}

String? _listingImageUrl(Map<String, dynamic> listing) {
  final images = listing['images'];
  if (images is! List || images.isEmpty) return null;

  final firstImage = images.first;
  final rawUrl = firstImage is Map
      ? firstImage['image']?.toString()
      : firstImage?.toString();
  if (rawUrl == null || rawUrl.trim().isEmpty) return null;

  final uri = Uri.tryParse(rawUrl);
  if (uri == null) return null;
  if (uri.hasScheme) return rawUrl;

  final baseUri = Uri.tryParse(ApiClient.baseUrl);
  return baseUri?.resolve(rawUrl).toString();
}

class _BusinessTile extends StatelessWidget {
  const _BusinessTile({
    required this.business,
  });

  final Map<String, dynamic> business;

  @override
  Widget build(BuildContext context) {
    final businessId = business['id'] is int
        ? business['id'] as int
        : int.tryParse(business['id']?.toString() ?? '');
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
            Card(
              child: ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.person),
              ),
              title: const Text(
                'Your BluuBase account',
              ),
              subtitle: const Text(
                'Campus marketplace member',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openBusinessProfile(context),
              ),
            ),

            Card(
              child: ListTile(
                leading: const Icon(Icons.favorite_outline),
                title: const Text('Favorites'),
                subtitle: const Text(
                  'Products and services you have saved',
                ),
                trailing: const Icon(
                  Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const FavoritesScreen(),
                    ),
                  );
                },
              ),
            ),

            Card(
              child: ListTile(
                leading: const Icon(Icons.insights_outlined),
                title: const Text('Business analytics'),
                subtitle: const Text(
                  'Views, followers, listings, and customer feedback',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const BusinessAnalyticsScreen(),
                    ),
                  );
                },
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

  Future<void> _openBusinessProfile(BuildContext context) async {
    try {
      final token = await const TokenStorage().getToken();
      if (token == null || token.isEmpty) {
        throw Exception('Please log in again to open your business profile.');
      }

      final response = await Dio().get(
        '${ApiClient.baseUrl}/businessprofiles/mine/',
        options: Options(headers: {'Authorization': 'Token $token'}),
      );
      final business = Map<String, dynamic>.from(response.data as Map);
      final id = business['id'] is int
          ? business['id'] as int
          : int.tryParse(business['id']?.toString() ?? '');
      if (id == null || !context.mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => BusinessProfileScreen(businessId: id),
        ),
      );
    } on DioException catch (error) {
      if (!context.mounted) return;
      if (error.response?.statusCode == 404) {
        final created = await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CreateBusinessScreen()),
        );
        final createdBusiness = created is Map
            ? Map<String, dynamic>.from(created)
            : null;
        final createdId = createdBusiness?['id'] is int
            ? createdBusiness!['id'] as int
            : int.tryParse(createdBusiness?['id']?.toString() ?? '');
        if (createdId != null && context.mounted) {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => BusinessProfileScreen(businessId: createdId),
            ),
          );
        }
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open your business profile.')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
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
  const _EmptyView({
    this.message = 'No listings yet',
    this.helper = 'Pull down to refresh after listings are added.',
  });

  final String message;
  final String helper;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 80),
      child: Column(
        children: [
          const Icon(
            Icons.inventory_2_outlined,
            size: 52,
          ),
          const SizedBox(height: 12),
          Text(message),
          const SizedBox(height: 6),
          Text(
            helper,
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
