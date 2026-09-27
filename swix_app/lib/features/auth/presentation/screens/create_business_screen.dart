import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/services/token_storage.dart';

class CreateBusinessScreen extends StatefulWidget {
  const CreateBusinessScreen({super.key});

  @override
  State<CreateBusinessScreen> createState() => _CreateBusinessScreenState();
}

class _CreateBusinessScreenState extends State<CreateBusinessScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  late Future<List<_Category>> _categories;

  int? _categoryId;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _categories = _loadCategories();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<List<_Category>> _loadCategories() async {
    final response = await Dio().get(
      '${ApiClient.baseUrl}/categories/',
    );

    final data = response.data;

    final items = data is Map
        ? data['results'] as List? ?? const []
        : data as List;

    return items
        .map(
          (item) => _Category.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  Future<void> _createBusiness() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_categoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choose a business category.'),
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final token = await const TokenStorage().getToken();

      if (token == null || token.isEmpty) {
        throw Exception('Session expired. Please log in again.');
      }

      final response = await Dio().post(
        '${ApiClient.baseUrl}/businessprofiles/',
        data: {
          'name': _nameController.text.trim(),
          'description': _descriptionController.text.trim(),
          'category': _categoryId,
        },
        options: Options(
          headers: {
            'Authorization': 'Token $token',
          },
        ),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Business profile created successfully.'),
        ),
      );

      Navigator.of(context).pop(response.data);
    } on DioException catch (e) {
      if (!mounted) return;

      String message = 'Could not create your business profile.';

      final data = e.response?.data;

      if (data is Map) {
        if (data['detail'] != null) {
          message = data['detail'].toString();
        } else if (data['name'] != null) {
          message = data['name'].toString();
        } else if (data['category'] != null) {
          message = data['category'].toString();
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create business'),
      ),
      body: FutureBuilder<List<_Category>>(
        future: _categories,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: FilledButton(
                onPressed: () {
                  setState(() {
                    _categories = _loadCategories();
                  });
                },
                child: const Text('Retry'),
              ),
            );
          }

          final categories = snapshot.data ?? [];

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Start selling on SWIX',
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),

                    const SizedBox(height: 8),

                    const Text(
                      'Create your business profile before adding products or services.',
                    ),

                    const SizedBox(height: 28),

                    TextFormField(
                      controller: _nameController,
                      enabled: !_isSubmitting,
                      decoration: const InputDecoration(
                        labelText: 'Business name',
                        hintText: 'e.g. Leo Sneakers',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Enter your business name';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    DropdownButtonFormField<int>(
                      initialValue: _categoryId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                      ),
                      items: categories
                          .map(
                            (category) => DropdownMenuItem<int>(
                              value: category.id,
                              child: Text(category.name),
                            ),
                          )
                          .toList(),
                      onChanged: _isSubmitting
                          ? null
                          : (value) {
                              setState(() {
                                _categoryId = value;
                              });
                            },
                      validator: (value) {
                        if (value == null) {
                          return 'Choose a category';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _descriptionController,
                      enabled: !_isSubmitting,
                      minLines: 4,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        hintText:
                            'Tell students what your business offers...',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                    ),

                    const SizedBox(height: 24),

                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        onPressed: _isSubmitting
                            ? null
                            : _createBusiness,
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(),
                              )
                            : const Text('Create business'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Category {
  const _Category({
    required this.id,
    required this.name,
  });

  final int id;
  final String name;

  factory _Category.fromJson(
    Map<String, dynamic> json,
  ) {
    return _Category(
      id: json['id'] as int,
      name: json['name'] as String,
    );
  }
}