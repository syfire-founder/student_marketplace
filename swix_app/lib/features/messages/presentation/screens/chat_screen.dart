import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/services/token_storage.dart';


class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.sellerName,
    this.productId,
    this.productName,
    this.productImage,
  });

  final int conversationId;
  final String sellerName;
  final int? productId;
  final String? productName;
  final String? productImage;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}


class _ChatScreenState extends State<ChatScreen> {
  final _composer = TextEditingController();
  final _scrollController = ScrollController();

  late final Dio _dio;
  Timer? _refreshTimer;
  int? _pendingProductId;
  String? _pendingProductName;
  String? _pendingProductImage;
  Map<String, dynamic>? _replyToMessage;

  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _pendingProductId = widget.productId;
    _pendingProductName = widget.productName;
    _pendingProductImage = widget.productImage;

    _dio = Dio(
      BaseOptions(
        baseUrl: ApiClient.baseUrl,
      ),
    );

    _loadInitialMessages();

    // Check for new messages every 3 seconds.
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _refreshMessages(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _composer.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<Options> _authorizedOptions() async {
    final token = await const TokenStorage().getToken();

    return Options(
      headers: {
        'Authorization': 'Token $token',
      },
    );
  }



  Future<List<Map<String, dynamic>>> _fetchMessages() async {
    final options = await _authorizedOptions();

    final allMessages = <Map<String, dynamic>>[];
    String? nextUrl = '/messages/?conversation=${widget.conversationId}';

    while (nextUrl != null) {
      final response = await _dio.get(
        nextUrl,
        options: options,
      );

      final body = response.data;
      final items = body is Map ? body['results'] : body;

      if (items is! List) {
        break;
      }

      allMessages.addAll(
        items.map(
          (item) => Map<String, dynamic>.from(item as Map),
        ),
      );

      final next = body is Map ? body['next'] : null;

      if (next == null) {
        nextUrl = null;
      } else {
        // Convert Django's full pagination URL into a path
        // relative to the existing Dio base URL.
        final uri = Uri.parse(next.toString());
        final basePath = Uri.parse(ApiClient.baseUrl).path;
        var requestPath = uri.path;

        if (basePath.isNotEmpty &&
            requestPath.startsWith(basePath)) {
          requestPath = requestPath.substring(basePath.length);
        }

        if (!requestPath.startsWith('/')) {
          requestPath = '/$requestPath';
        }

        nextUrl =
            '$requestPath${uri.hasQuery ? '?${uri.query}' : ''}';
      }
    }

    return allMessages;
  }


  Future<List<Map<String, dynamic>>> _fetchNewMessages() async {
    if (_messages.isEmpty) {
      return _fetchMessages();
    }

    final latestId = _messages
        .map((message) => int.tryParse(message['id'].toString()) ?? 0)
        .reduce((a, b) => a > b ? a : b);

    final options = await _authorizedOptions();

    final response = await _dio.get(
      '/messages/',
      queryParameters: {
        'conversation': widget.conversationId,
        'after': latestId,
      },
      options: options,
    );

    final body = response.data;
    final items = body is Map ? body['results'] : body;

    if (items is! List) {
      return [];
    }

    return items
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }


  Future<void> _markConversationAsRead() async {
    try {
      await _dio.post(
        '/conversations/${widget.conversationId}/mark-read/',
        options: await _authorizedOptions(),
      );
    } on DioException {
      // Keep displaying messages if marking them as read fails.
    }
  }



  Future<void> _loadInitialMessages() async {
    try {
      final messages = await _fetchMessages();
      await _markConversationAsRead();

      if (!mounted) {
        return;
      }

      setState(() {
        _messages = messages;
        _isLoading = false;
        _errorMessage = null;
      });

      _scrollToLatest();
    } on DioException {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = 'Could not load messages.';
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = 'Could not load messages.';
      });
    }
  }


  Future<void> _refreshMessages() async {
    if (_isLoading) {
      return;
    }

    try {
      final newMessages = await _fetchNewMessages();

      if (!mounted || newMessages.isEmpty) {
        return;
      }

      final existingIds = _messages
        .map((message) => message['id'].toString())
        .toSet();

      final uniqueNewMessages = newMessages.where(
        (message) => !existingIds.contains(message['id'].toString()),
      ).toList();

      if (uniqueNewMessages.isEmpty) {
        return;
      }

      setState(() {
        _messages.addAll(uniqueNewMessages);
        _messages.sort((a, b) {
          final aId = int.tryParse(a['id'].toString()) ?? 0;
          final bId = int.tryParse(b['id'].toString()) ?? 0;
          return aId.compareTo(bId);
        });
        _errorMessage = null;
      });

      await _markConversationAsRead();

      _scrollToLatest();
    } on DioException {
      // Keep displaying existing messages if background refresh fails.
    } catch (_) {
      // Keep displaying existing messages if background refresh fails.
    }
  }



  Future<void> _sendMessage() async {
    debugPrint('SEND BUTTON TAPPED');
    final text = _composer.text.trim();
    debugPrint('MESSAGE TEXT: $text');

  // Keep the rest of your existing function unchanged.

    if (text.isEmpty || _isSending) {
      return;
    }

    final productId = _pendingProductId;
    final replyToMessage = _replyToMessage;
    final replyToId = replyToMessage?['id']?.toString();

    setState(() {
      _isSending = true;
    });

    try {
      await _dio.post(
        '/messages/',
        data: {
          'conversation': widget.conversationId,
          'text': text,
          if (productId != null) 'product': productId,
          if (replyToMessage != null) 'reply_to': replyToMessage['id'],
        },
        options: await _authorizedOptions(),
      );

      _composer.clear();
      if (mounted && (productId != null || replyToMessage != null)) {
        setState(() {
          if (productId != null && _pendingProductId == productId) {
            _pendingProductId = null;
            _pendingProductName = null;
            _pendingProductImage = null;
          }
          if (replyToId != null &&
              _replyToMessage?['id']?.toString() == replyToId) {
            _replyToMessage = null;
          }
        });
      }
      await _refreshMessages();
    } on DioException catch (error) {
      debugPrint('SEND MESSAGE FAILED');
      debugPrint('Request URL: ${error.requestOptions.uri}');
      debugPrint('HTTP status: ${error.response?.statusCode}');
      debugPrint('Response body: ${error.response?.data}');
      debugPrint('Dio error: ${error.message}');

      if (!mounted) {
        return;
      }

      final details = error.response?.data?.toString()
          ?? error.message
          ?? 'Unknown error';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Message failed: $details'),
          duration: const Duration(seconds: 6),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }


  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  void _selectMessageForReply(Map<String, dynamic> message) {
    if (_isSending) return;
    setState(() => _replyToMessage = message);
  }

  Widget _buildReplyPreview(BuildContext context) {
    final message = _replyToMessage;
    if (message == null) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    final sender = message['is_mine'] == true
        ? 'your message'
        : (message['sender']?.toString() ?? 'message');
    final text = message['text']?.toString().trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        border: Border(
          left: BorderSide(color: colorScheme.primary, width: 3),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Replying to $sender',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                Text(
                  text?.isNotEmpty == true ? text! : 'Product or service',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _replyToMessage = null),
            icon: const Icon(Icons.close, size: 18),
            tooltip: 'Cancel reply',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _replySwipeBackground(BuildContext context, Alignment alignment) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: alignment,
      child: Icon(Icons.reply, color: colorScheme.onPrimaryContainer),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.sellerName),
      ),
      body: Column(
        children: [
          Expanded(
            child: _buildMessagesArea(),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                16,
                8,
                16,
                12,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_replyToMessage != null) ...[
                    _buildReplyPreview(context),
                    const SizedBox(height: 8),
                  ],
                  if (_pendingProductId != null) ...[
                    _buildPendingProductPreview(context),
                    const SizedBox(height: 8),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _composer,
                          minLines: 1,
                          maxLines: 4,
                          textCapitalization:
                              TextCapitalization.sentences,
                          onSubmitted: (_) => _sendMessage(),
                          decoration: const InputDecoration(
                            hintText: 'Write a message',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: _isSending ? null : _sendMessage,
                        icon: _isSending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send),
                        tooltip: 'Send message',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingProductPreview(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final imageUrl = _pendingProductImage;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 48,
              height: 48,
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) => ColoredBox(
                        color: colorScheme.surface,
                        child: Icon(
                          Icons.image_not_supported_outlined,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ColoredBox(
                      color: colorScheme.surface,
                      child: Icon(
                        Icons.shopping_bag_outlined,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'First message about',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
                Text(
                  _pendingProductName?.isNotEmpty == true
                      ? _pendingProductName!
                      : 'Selected listing',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesArea() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null && _messages.isEmpty) {
      return Center(
        child: TextButton(
          onPressed: () {
            setState(() {
              _isLoading = true;
              _errorMessage = null;
            });

            _loadInitialMessages();
          },
          child: const Text(
            'Could not load messages. Try again.',
          ),
        ),
      );
    }

    if (_messages.isEmpty) {
      return const Center(
        child: Text(
          'Say hello to start the conversation.',
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        return Dismissible(
          key: ValueKey('message-${message['id']}'),
          direction: DismissDirection.horizontal,
          dismissThresholds: const {
            DismissDirection.horizontal: 0.18,
          },
          background: _replySwipeBackground(
            context,
            Alignment.centerLeft,
          ),
          secondaryBackground: _replySwipeBackground(
            context,
            Alignment.centerRight,
          ),
          confirmDismiss: (_) async {
            _selectMessageForReply(message);
            return false;
          },
          child: _MessageBubble(
            message: message,
          ),
        );
      },
    );
  }
}


class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
  });

  final Map<String, dynamic> message;

  @override
  Widget build(BuildContext context) {
    final isMine = message['is_mine'] == true;
    final colorScheme = Theme.of(context).colorScheme;
    final productName = message['product_name']?.toString().trim();
    final productImage = message['product_image']?.toString().trim();
    final replyText = message['reply_to_text']?.toString().trim();
    final replySender = message['reply_to_sender']?.toString().trim();

    return Align(
      alignment:
          isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 10,
        ),
        constraints: const BoxConstraints(
          maxWidth: 300,
        ),
        decoration: BoxDecoration(
          color: isMine
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (replyText != null && replyText.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.surface.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border(
                    left: BorderSide(color: colorScheme.primary, width: 3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      replySender?.isNotEmpty == true
                          ? replySender!
                          : 'Message',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    Text(
                      replyText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (productImage != null && productImage.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: double.infinity,
                  height: 150,
                  child: CachedNetworkImage(
                    imageUrl: productImage,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => ColoredBox(
                      color: colorScheme.surfaceContainerHighest,
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    errorWidget: (context, url, error) => ColoredBox(
                      color: colorScheme.surfaceContainerHighest,
                      child: Icon(
                        Icons.image_not_supported_outlined,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (productName != null && productName.isNotEmpty) ...[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.shopping_bag_outlined,
                    size: 14,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      productName,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ],
            Text(
              message['text']?.toString() ?? '',
            ),
          ],
        ),
      ),
    );
  }
}
