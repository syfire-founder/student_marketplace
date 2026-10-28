import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/services/token_storage.dart';

class BusinessReviewsSection extends StatefulWidget {
  const BusinessReviewsSection({
    super.key,
    required this.businessId,
    required this.businessName,
    this.canReview = true,
  });

  final int businessId;
  final String businessName;
  final bool canReview;

  @override
  State<BusinessReviewsSection> createState() =>
      _BusinessReviewsSectionState();
}

class _BusinessReviewsSectionState extends State<BusinessReviewsSection> {
  final Dio _dio = Dio();
  late Future<List<Map<String, dynamic>>> _reviews;

  @override
  void initState() {
    super.initState();
    _reviews = _loadReviews();
  }

  Future<List<Map<String, dynamic>>> _loadReviews() async {
    final token = await const TokenStorage().getToken();
    final headers = token == null || token.isEmpty
        ? null
        : {'Authorization': 'Token $token'};
    final result = <Map<String, dynamic>>[];
    String? nextPage = '${ApiClient.baseUrl}/reviews/';
    var firstPage = true;

    while (nextPage != null) {
      final response = await _dio.get(
        nextPage,
        queryParameters: firstPage ? {'business': widget.businessId} : null,
        options: Options(headers: headers),
      );
      firstPage = false;
      final data = response.data;
      final pageResults = data is Map ? data['results'] : data;
      if (pageResults is List) {
        result.addAll(
          pageResults
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item)),
        );
      }
      nextPage = data is Map ? data['next']?.toString() : null;
    }
    return result;
  }

  Future<void> _refresh() async {
    final request = _loadReviews();
    if (!mounted) return;
    setState(() => _reviews = request);
    await request;
  }

  Future<void> _writeReview(List<Map<String, dynamic>> reviews) async {
    final token = await const TokenStorage().getToken();
    if (token == null || token.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to write a review.')),
      );
      return;
    }

    final existing = reviews.where((review) => review['is_owner'] == true);
    final ownReview = existing.isEmpty ? null : existing.first;
    final draft = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _ReviewComposer(
        initialRating: _asInt(ownReview?['rating']) ?? 5,
        initialComment: ownReview?['comment']?.toString() ?? '',
        isEditing: ownReview != null,
        businessName: widget.businessName,
      ),
    );
    if (draft == null || !mounted) return;

    try {
      final headers = {'Authorization': 'Token $token'};
      if (ownReview == null) {
        await _dio.post(
          '${ApiClient.baseUrl}/reviews/',
          data: {
            'business': widget.businessId,
            'rating': draft['rating'],
            'comment': draft['comment'],
          },
          options: Options(headers: headers),
        );
      } else {
        await _dio.patch(
          '${ApiClient.baseUrl}/reviews/${ownReview['id']}/',
          data: {
            'rating': draft['rating'],
            'comment': draft['comment'],
          },
          options: Options(headers: headers),
        );
      }
      if (!mounted) return;
      await _refresh();
    } on DioException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage(error))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _reviews,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Reviews', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              const Text('Could not load reviews.'),
              TextButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ],
          );
        }

        final reviews = snapshot.data ?? const <Map<String, dynamic>>[];
        final average = reviews.isEmpty
            ? 0.0
            : reviews
                    .map((review) => _asInt(review['rating']) ?? 0)
                    .reduce((a, b) => a + b) /
                reviews.length;
        final ownReview = reviews.any((review) => review['is_owner'] == true);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Business rating & reviews',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  reviews.isEmpty ? 'No ratings yet' : average.toStringAsFixed(1),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                if (reviews.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  _Stars(rating: average.round()),
                  const SizedBox(width: 8),
                  Text('(${reviews.length})'),
                ],
                if (widget.canReview) ...[
                  const Spacer(),
                  TextButton(
                    onPressed: () => _writeReview(reviews),
                    child: Text(
                      ownReview ? 'Edit yours' : 'Rate this business',
                    ),
                  ),
                ],
              ],
            ),
            if (reviews.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text('Share your experience with this business.'),
              )
            else
              ...reviews.map((review) => _ReviewCard(review: review)),
          ],
        );
      },
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});

  final Map<String, dynamic> review;

  @override
  Widget build(BuildContext context) {
    final comment = review['comment']?.toString().trim() ?? '';
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    review['user']?.toString() ?? 'Marketplace user',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                _Stars(rating: _asInt(review['rating']) ?? 0),
              ],
            ),
            if (comment.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(comment),
            ],
          ],
        ),
      ),
    );
  }
}

class _Stars extends StatelessWidget {
  const _Stars({required this.rating});

  final int rating;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        5,
        (index) => Icon(
          index < rating ? Icons.star : Icons.star_border,
          size: 18,
          color: Colors.amber.shade700,
        ),
      ),
    );
  }
}

class _ReviewComposer extends StatefulWidget {
  const _ReviewComposer({
    required this.initialRating,
    required this.initialComment,
    required this.isEditing,
    required this.businessName,
  });

  final int initialRating;
  final String initialComment;
  final bool isEditing;
  final String businessName;

  @override
  State<_ReviewComposer> createState() => _ReviewComposerState();
}

class _ReviewComposerState extends State<_ReviewComposer> {
  late int _rating = widget.initialRating;
  late final TextEditingController _commentController =
      TextEditingController(text: widget.initialComment);

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isEditing ? 'Edit your review' : 'Rate ${widget.businessName}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Your rating'),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              5,
              (index) => IconButton(
                onPressed: () => setState(() => _rating = index + 1),
                icon: Icon(
                  index < _rating ? Icons.star : Icons.star_border,
                  color: Colors.amber.shade700,
                ),
              ),
            ),
          ),
          TextField(
            controller: _commentController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Review (optional)',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop({
            'rating': _rating,
            'comment': _commentController.text.trim(),
          }),
          child: Text(widget.isEditing ? 'Save' : 'Submit'),
        ),
      ],
    );
  }
}

int? _asInt(dynamic value) =>
    value is int ? value : int.tryParse(value?.toString() ?? '');

String _errorMessage(DioException error) {
  final data = error.response?.data;
  if (data is Map) {
    final detail = data['detail']?.toString();
    if (detail != null && detail.isNotEmpty) return detail;
    for (final value in data.values) {
      if (value is List && value.isNotEmpty) return value.first.toString();
      if (value is String && value.isNotEmpty) return value;
    }
  }
  return 'Could not save your review. Please try again.';
}
