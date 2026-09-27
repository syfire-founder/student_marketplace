import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/services/token_storage.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.sellerName,
  });

  final int conversationId;
  final String sellerName;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _composer = TextEditingController();
  final _scrollController = ScrollController();

  late final Dio _dio;
  Timer? _refreshTimer;

  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

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
    final response = await _dio.get(
      '/messages/',
      queryParameters: {
        'conversation': widget.conversationId,
      },
      options: await _authorizedOptions(),
    );

    try {
      await _dio.post(
        '/conversations/${widget.conversationId}/mark-read/',
        options: await _authorizedOptions(),
      );
    } on DioException {
      // Messages can still be displayed if marking them as read fails.
    }

    final body = response.data;
    final items = body is Map ? body['results'] : body;

    if (items is! List) {
      return [];
    }

    return items
        .map(
          (item) => Map<String, dynamic>.from(item as Map),
        )
        .toList();
  }

  Future<void> _loadInitialMessages() async {
    try {
      final messages = await _fetchMessages();

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
    // Don't start another request if the initial request is still loading.
    if (_isLoading) {
      return;
    }

    try {
      final messages = await _fetchMessages();

      if (!mounted) {
        return;
      }

      final hadNewMessages = messages.length > _messages.length;

      setState(() {
        _messages = messages;
        _errorMessage = null;
      });

      if (hadNewMessages) {
        _scrollToLatest();
      }
    } on DioException {
      // Keep displaying the existing messages if a background refresh fails.
    } catch (_) {
      // Keep displaying the existing messages if a background refresh fails.
    }
  }

  Future<void> _sendMessage() async {
    final text = _composer.text.trim();

    if (text.isEmpty || _isSending) {
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      await _dio.post(
        '/messages/',
        data: {
          'conversation': widget.conversationId,
          'text': text,
        },
        options: await _authorizedOptions(),
      );

      _composer.clear();

      await _refreshMessages();
    } on DioException {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Message could not be sent. Try again.',
          ),
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
              child: Row(
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
        return _MessageBubble(
          message: _messages[index],
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
        child: Text(
          message['text']?.toString() ?? '',
        ),
      ),
    );
  }
}