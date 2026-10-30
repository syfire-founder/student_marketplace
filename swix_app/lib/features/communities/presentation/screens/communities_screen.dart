import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/services/token_storage.dart';

class CommunitiesScreen extends StatefulWidget {
  const CommunitiesScreen({super.key});

  @override
  State<CommunitiesScreen> createState() => _CommunitiesScreenState();
}

class _CommunitiesScreenState extends State<CommunitiesScreen> {
  late Future<List<Map<String, dynamic>>> _communities;
  final Set<int> _joining = {};

  @override
  void initState() {
    super.initState();
    _communities = _loadCommunities();
  }

  Future<List<Map<String, dynamic>>> _loadCommunities() async {
    final token = await const TokenStorage().getToken();
    final items = <Map<String, dynamic>>[];
    String? next = '${ApiClient.baseUrl}/communities/';
    while (next != null) {
      final response = await Dio().get(
        next,
        options: Options(headers: {'Authorization': 'Token $token'}),
      );
      final body = response.data;
      final results = body is Map ? body['results'] : body;
      if (results is List) {
        items.addAll(results.map((item) => Map<String, dynamic>.from(item as Map)));
      }
      final nextPage = body is Map ? body['next'] : null;
      if (nextPage == null) {
        next = null;
      } else {
        final uri = Uri.parse(nextPage.toString());
        final path = uri.path.startsWith('/api/')
            ? uri.path.substring(4)
            : uri.path;
        next = '${ApiClient.baseUrl}$path${uri.hasQuery ? '?${uri.query}' : ''}';
      }
    }
    return items;
  }

  Future<void> _refresh() async {
    final request = _loadCommunities();
    setState(() => _communities = request);
    await request;
  }

  Future<void> _openCommunity(Map<String, dynamic> business) async {
    final joined = business['is_member'] == true;
    final id = _toInt(business['id']);
    if (id == null) return;
    if (!joined) {
      setState(() => _joining.add(id));
      try {
        final token = await const TokenStorage().getToken();
        await Dio().post(
          '${ApiClient.baseUrl}/communities/$id/join/',
          options: Options(headers: {'Authorization': 'Token $token'}),
        );
        business['is_member'] = true;
      } on DioException catch (error) {
        if (mounted) {
          final detail = error.response?.data is Map
              ? (error.response?.data['detail']?.toString() ?? 'Could not join this community.')
              : 'Could not join this community.';
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(detail)));
        }
        return;
      } finally {
        if (mounted) setState(() => _joining.remove(id));
      }
    }
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => BusinessCommunityScreen(business: business),
      ),
    );
    if (mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _communities,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: TextButton(onPressed: _refresh, child: const Text('Could not load communities. Try again.')),
          );
        }
        final communities = snapshot.data ?? const [];
        if (communities.isEmpty) {
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 150),
                Icon(Icons.groups_outlined, size: 48),
                SizedBox(height: 12),
                Center(child: Text('Follow a business to find its community here.')),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: communities.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final business = communities[index];
              final id = _toInt(business['id']);
              final isMember = business['is_member'] == true;
              final latest = business['latest_post'];
              final preview = latest is Map
                  ? (latest['message']?.toString().trim().isNotEmpty == true
                      ? latest['message'].toString()
                      : 'Shared a ${latest['media_type'] ?? 'community'} update')
                  : isMember
                      ? 'Community updates and announcements'
                      : 'Join to see this business’s updates';
              return Card(
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  leading: _BusinessAvatar(
                    name: business['name']?.toString() ?? 'Business',
                    imageUrl: business['logo']?.toString(),
                  ),
                  title: Text(business['name']?.toString() ?? 'Business'),
                  subtitle: Text(preview, maxLines: 2, overflow: TextOverflow.ellipsis),
                  trailing: _joining.contains(id)
                      ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2))
                      : isMember
                          ? const Icon(Icons.chevron_right)
                          : FilledButton.tonal(onPressed: id == null ? null : () => _openCommunity(business), child: const Text('Join')),
                  onTap: isMember ? () => _openCommunity(business) : null,
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class BusinessCommunityScreen extends StatefulWidget {
  const BusinessCommunityScreen({super.key, required this.business});

  final Map<String, dynamic> business;

  @override
  State<BusinessCommunityScreen> createState() => _BusinessCommunityScreenState();
}

class _BusinessCommunityScreenState extends State<BusinessCommunityScreen> {
  late Future<List<Map<String, dynamic>>> _posts;

  int get _businessId => _toInt(widget.business['id']) ?? 0;
  bool get _isOwner => widget.business['is_owner'] == true;

  @override
  void initState() {
    super.initState();
    _posts = _loadPosts();
  }

  Future<List<Map<String, dynamic>>> _loadPosts() async {
    final token = await const TokenStorage().getToken();
    final response = await Dio().get(
      '${ApiClient.baseUrl}/community-posts/?business=$_businessId',
      options: Options(headers: {'Authorization': 'Token $token'}),
    );
    final body = response.data;
    final results = body is Map ? body['results'] : body;
    if (results is! List) return const [];
    return results.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  Future<void> _refresh() async {
    final request = _loadPosts();
    setState(() => _posts = request);
    await request;
  }

  Future<void> _composePost() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => CommunityPostComposerScreen(
        businessId: _businessId,
        businessName: widget.business['name']?.toString() ?? 'Business',
      )),
    );
    if (created == true && mounted) _refresh();
  }

  Future<void> _leaveCommunity() async {
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave community?'),
        content: const Text('You will need to follow the business again before joining.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Leave')),
        ],
      ),
    );
    if (shouldLeave != true) return;
    final token = await const TokenStorage().getToken();
    await Dio().post(
      '${ApiClient.baseUrl}/communities/$_businessId/leave/',
      options: Options(headers: {'Authorization': 'Token $token'}),
    );
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.business['name']?.toString() ?? 'Business community';
    return Scaffold(
      appBar: AppBar(
        title: Text(name),
        actions: [
          if (_isOwner)
            IconButton(onPressed: _composePost, tooltip: 'Post an update', icon: const Icon(Icons.add_circle_outline)),
          if (!_isOwner)
            PopupMenuButton<String>(
              onSelected: (value) { if (value == 'leave') _leaveCommunity(); },
              itemBuilder: (_) => const [PopupMenuItem(value: 'leave', child: Text('Leave community'))],
            ),
        ],
      ),
      floatingActionButton: _isOwner
          ? FloatingActionButton.extended(onPressed: _composePost, icon: const Icon(Icons.edit), label: const Text('Post update'))
          : null,
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _posts,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: TextButton(onPressed: _refresh, child: const Text('Could not load updates. Try again.')));
          }
          final posts = snapshot.data ?? const [];
          if (posts.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 150),
                  Icon(Icons.campaign_outlined, size: 48),
                  SizedBox(height: 12),
                  Center(child: Text('No community updates yet.')),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
              itemCount: posts.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) => _CommunityPostCard(post: posts[index]),
            ),
          );
        },
      ),
    );
  }
}

class CommunityPostComposerScreen extends StatefulWidget {
  const CommunityPostComposerScreen({super.key, required this.businessId, required this.businessName});

  final int businessId;
  final String businessName;

  @override
  State<CommunityPostComposerScreen> createState() => _CommunityPostComposerScreenState();
}

class _CommunityPostComposerScreenState extends State<CommunityPostComposerScreen> {
  final _message = TextEditingController();
  final _picker = ImagePicker();
  XFile? _media;
  Uint8List? _mediaBytes;
  String? _mediaType;
  bool _sending = false;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _pick(String type) async {
    final file = type == 'image'
        ? await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85)
        : await _picker.pickVideo(source: ImageSource.gallery, maxDuration: const Duration(minutes: 3));
    if (file != null && mounted) {
      final bytes = type == 'image' ? await file.readAsBytes() : null;
      if (!mounted) return;
      setState(() { _media = file; _mediaType = type; _mediaBytes = bytes; });
    }
  }

  Future<void> _submit() async {
    if (_message.text.trim().isEmpty && _media == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Write an update or add a photo or video.')));
      return;
    }
    setState(() => _sending = true);
    try {
      final token = await const TokenStorage().getToken();
      final data = FormData.fromMap({
        'business': widget.businessId,
        'message': _message.text.trim(),
        if (_media != null) 'media_type': _mediaType,
        if (_media != null) 'media': await MultipartFile.fromFile(_media!.path, filename: _media!.name),
      });
      await Dio().post(
        '${ApiClient.baseUrl}/community-posts/',
        data: data,
        options: Options(headers: {'Authorization': 'Token $token'}),
      );
      if (mounted) Navigator.pop(context, true);
    } on DioException catch (error) {
      if (mounted) {
        final data = error.response?.data;
        final detail = data is Map ? data.values.expand((value) => value is List ? value : [value]).join(' ') : 'Could not publish this update.';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(detail.toString())));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Community update')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Posting to ${widget.businessName}', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 16),
        TextField(
          controller: _message,
          minLines: 4,
          maxLines: 8,
          maxLength: 3000,
          decoration: const InputDecoration(
            labelText: 'What would you like to share?',
            hintText: 'Share business news, service updates, or useful information.',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 10, children: [
          OutlinedButton.icon(onPressed: _sending ? null : () => _pick('image'), icon: const Icon(Icons.photo_outlined), label: const Text('Add photo')),
          OutlinedButton.icon(onPressed: _sending ? null : () => _pick('video'), icon: const Icon(Icons.videocam_outlined), label: const Text('Add video')),
        ]),
        if (_media != null) ...[
          const SizedBox(height: 12),
          if (_mediaType == 'image' && _mediaBytes != null)
            ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(_mediaBytes!, height: 190, width: double.infinity, fit: BoxFit.cover))
          else
            Container(height: 100, decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)), child: const Center(child: Icon(Icons.video_file_outlined, size: 42))),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(onPressed: () => setState(() { _media = null; _mediaType = null; _mediaBytes = null; }), icon: const Icon(Icons.close), label: const Text('Remove attachment')),
          ),
        ],
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _sending ? null : _submit,
          icon: _sending ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send_outlined),
          label: Text(_sending ? 'Publishing…' : 'Publish update'),
        ),
        const SizedBox(height: 8),
        Text('Photos and videos can be up to 50 MB. Videos are limited to 3 minutes.', style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );
}

class _CommunityPostCard extends StatelessWidget {
  const _CommunityPostCard({required this.post});
  final Map<String, dynamic> post;

  @override
  Widget build(BuildContext context) {
    final media = post['media']?.toString();
    final mediaType = post['media_type']?.toString();
    final message = post['message']?.toString().trim() ?? '';
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ListTile(
          leading: CircleAvatar(child: Icon(Icons.storefront_outlined, color: Theme.of(context).colorScheme.primary)),
          title: Text(post['business_name']?.toString() ?? 'Business'),
          subtitle: Text(_formatDate(post['created_at']?.toString())),
        ),
        if (message.isNotEmpty) Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12), child: Text(message)),
        if (media != null && media.isNotEmpty)
          if (mediaType == 'video')
            _CommunityVideo(url: media)
          else
            CachedNetworkImage(
              imageUrl: media,
              width: double.infinity,
              fit: BoxFit.cover,
              placeholder: (_, _) => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
              errorWidget: (_, _, _) => const SizedBox(height: 160, child: Center(child: Icon(Icons.broken_image_outlined))),
            ),
        const SizedBox(height: 8),
      ]),
    );
  }
}

class _CommunityVideo extends StatefulWidget {
  const _CommunityVideo({required this.url});
  final String url;

  @override
  State<_CommunityVideo> createState() => _CommunityVideoState();
}

class _CommunityVideoState extends State<_CommunityVideo> {
  VideoPlayerController? _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) { if (mounted) setState(() {}); }).catchError((_) { if (mounted) setState(() => _error = 'Video could not be loaded.'); });
  }

  @override
  void dispose() { _controller?.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (_error != null || controller == null) {
      return SizedBox(height: 180, child: Center(child: Text(_error ?? 'Video unavailable.')));
    }
    if (!controller.value.isInitialized) {
      return const SizedBox(height: 180, child: Center(child: CircularProgressIndicator()));
    }
    return GestureDetector(
      onTap: () => setState(() => controller.value.isPlaying ? controller.pause() : controller.play()),
      child: Stack(alignment: Alignment.center, children: [
        AspectRatio(aspectRatio: controller.value.aspectRatio, child: VideoPlayer(controller)),
        DecoratedBox(
          decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(controller.value.isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 34),
          ),
        ),
        Positioned(left: 12, right: 12, bottom: 4, child: VideoProgressIndicator(controller, allowScrubbing: true, colors: VideoProgressColors(playedColor: Theme.of(context).colorScheme.primary))),
      ]),
    );
  }
}

class _BusinessAvatar extends StatelessWidget {
  const _BusinessAvatar({required this.name, this.imageUrl});
  final String name;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim() ?? '';
    return CircleAvatar(
      child: url.isEmpty
          ? Text(name.isEmpty ? 'B' : name.characters.first.toUpperCase())
          : ClipOval(child: CachedNetworkImage(imageUrl: url, width: 42, height: 42, fit: BoxFit.cover, errorWidget: (_, _, _) => const Icon(Icons.storefront_outlined))),
    );
  }
}

int? _toInt(dynamic value) => value is int ? value : int.tryParse(value?.toString() ?? '');

String _formatDate(String? raw) {
  final date = DateTime.tryParse(raw ?? '');
  if (date == null) return '';
  return DateFormat.yMMMd().add_jm().format(date.toLocal());
}
