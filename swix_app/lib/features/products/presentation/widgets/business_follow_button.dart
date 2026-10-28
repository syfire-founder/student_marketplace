import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/services/token_storage.dart';

class BusinessFollowButton extends StatefulWidget {
  const BusinessFollowButton({
    super.key,
    required this.businessId,
    this.compact = false,
  });

  final int businessId;
  final bool compact;

  @override
  State<BusinessFollowButton> createState() => _BusinessFollowButtonState();
}

class _BusinessFollowButtonState extends State<BusinessFollowButton> {
  final Dio _dio = Dio();
  bool _isFollowing = false;
  bool _isLoading = true;
  bool _isUpdating = false;
  int? _followId;

  @override
  void initState() {
    super.initState();
    _loadFollowStatus();
  }

  Future<void> _loadFollowStatus() async {
    try {
      final token = await const TokenStorage().getToken();
      if (token == null || token.isEmpty) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      String? nextPage = '${ApiClient.baseUrl}/business-follows/';
      while (nextPage != null) {
        final response = await _dio.get(
          nextPage,
          options: Options(headers: {'Authorization': 'Token $token'}),
        );
        final data = response.data;
        final results = data is Map ? data['results'] : data;
        if (results is List) {
          for (final item in results.whereType<Map>()) {
            final followedBusiness = item['business'];
            final followedBusinessId = followedBusiness is Map
                ? _toInt(followedBusiness['id'])
                : _toInt(followedBusiness);
            if (followedBusinessId == widget.businessId) {
              if (mounted) {
                setState(() {
                  _isFollowing = true;
                  _followId = _toInt(item['id']);
                  _isLoading = false;
                });
              }
              return;
            }
          }
        }
        nextPage = data is Map ? data['next']?.toString() : null;
      }
    } on DioException {
      // Keep the action available even if checking follow status fails.
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleFollow() async {
    if (_isUpdating) return;
    final token = await const TokenStorage().getToken();
    if (token == null || token.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to follow this business.')),
      );
      return;
    }

    setState(() => _isUpdating = true);
    try {
      final options = Options(headers: {'Authorization': 'Token $token'});
      if (_isFollowing && _followId != null) {
        await _dio.delete(
          '${ApiClient.baseUrl}/business-follows/$_followId/',
          options: options,
        );
        if (mounted) {
          setState(() {
            _isFollowing = false;
            _followId = null;
          });
        }
      } else {
        final response = await _dio.post(
          '${ApiClient.baseUrl}/business-follows/',
          data: {'business': widget.businessId},
          options: options,
        );
        if (mounted) {
          setState(() {
            _isFollowing = true;
            _followId = _toInt((response.data as Map)['id']);
          });
        }
      }
    } on DioException catch (error) {
      if (!mounted) return;
      final detail = error.response?.data is Map
          ? (error.response!.data as Map)['detail']?.toString()
          : null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(detail ?? 'Could not update follow status.')),
      );
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = _isFollowing ? 'Following' : 'Follow';
    if (widget.compact) {
      return OutlinedButton(
        onPressed: _isLoading || _isUpdating ? null : _toggleFollow,
        style: OutlinedButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        child: _isUpdating
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(_isLoading ? '…' : label),
      );
    }

    return OutlinedButton.icon(
      onPressed: _isLoading || _isUpdating ? null : _toggleFollow,
      icon: _isUpdating
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(_isFollowing ? Icons.check : Icons.add),
      label: Text(_isLoading ? 'Loading…' : label),
    );
  }
}

int? _toInt(dynamic value) =>
    value is int ? value : int.tryParse(value?.toString() ?? '');
