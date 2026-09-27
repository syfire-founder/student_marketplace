import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/services/token_storage.dart';

class CreateListingScreen extends ConsumerStatefulWidget {
  const CreateListingScreen({super.key});

  @override
  ConsumerState<CreateListingScreen> createState() =>
      _CreateListingScreenState();
}

class _CreateListingScreenState
    extends ConsumerState<CreateListingScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();

  final ImagePicker _imagePicker = ImagePicker();
  final List<XFile> _selectedImages = [];

  bool _isProduct = true;
  bool _isAvailable = true;
  bool _isPrivate = false;
  bool _isLoading = false;

  List<_Category> _categories = [];
  int? _categoryId;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // LOAD CATEGORIES
  // ---------------------------------------------------------------------------

  Future<void> _loadCategories() async {
    try {
      final response = await Dio().get(
        '${ApiClient.baseUrl}/categories/',
      );

      final data = response.data;

      final items = data is Map
          ? data['results'] as List? ?? const []
          : data as List;

      final categories = items
          .map(
            (item) => _Category.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();

      if (!mounted) return;

      setState(() {
        _categories = categories;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not load categories: $e',
          ),
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // PICK IMAGES
  // ---------------------------------------------------------------------------

  Future<void> _pickImages() async {
    if (_selectedImages.length >= 5) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'You can upload a maximum of 5 images.',
          ),
        ),
      );

      return;
    }

    try {
      final images = await _imagePicker.pickMultiImage(
        imageQuality: 85,
      );

      if (!mounted) return;

      if (images.isEmpty) return;

      final remainingSlots = 5 - _selectedImages.length;
      final selected = images.take(remainingSlots).toList();

      setState(() {
        _selectedImages.addAll(selected);
      });

      if (images.length > remainingSlots) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Only 5 images can be added to a listing.',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not select images: $e',
          ),
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // REMOVE IMAGE
  // ---------------------------------------------------------------------------

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  // ---------------------------------------------------------------------------
  // CREATE LISTING
  // ---------------------------------------------------------------------------

  Future<void> _createListing() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final token = await const TokenStorage().getToken();

      if (token == null || token.isEmpty) {
        throw Exception(
          'Your session has expired. Please log in again.',
        );
      }

      final priceText = _priceController.text.trim();

      // -----------------------------------------------------------------------
      // STEP 1: CREATE PRODUCT
      // -----------------------------------------------------------------------

      final response = await Dio().post(
        '${ApiClient.baseUrl}/products/',
        data: {
          'listing_type': _isProduct ? 'product' : 'service',
          'name': _nameController.text.trim(),
          'description': _descriptionController.text.trim(),
          'price': priceText.isEmpty ? null : priceText,
          'is_available': _isAvailable,
          'is_private': _isPrivate,
          if (_categoryId != null) 'category': _categoryId,
        },
        options: Options(
          headers: {
            'Authorization': 'Token $token',
          },
        ),
      );

      if (!mounted) return;

      final product = Map<String, dynamic>.from(
        response.data as Map,
      );

      final productId = product['id'];

      if (productId == null) {
        throw Exception(
          'Listing was created but no product ID was returned.',
        );
      }

      // -----------------------------------------------------------------------
      // STEP 2: UPLOAD IMAGES
      // -----------------------------------------------------------------------

      for (final image in _selectedImages) {
        final multipartFile = await MultipartFile.fromFile(
          image.path,
          filename: image.name,
        );

        final formData = FormData.fromMap({
          'product': productId,
          'image': multipartFile,
        });

        await Dio().post(
          '${ApiClient.baseUrl}/listing-images/',
          data: formData,
          options: Options(
            headers: {
              'Authorization': 'Token $token',
            },
          ),
        );
      }

      // -----------------------------------------------------------------------
      // STEP 3: SUCCESS
      // -----------------------------------------------------------------------

      if (!mounted) return;

      final messenger = ScaffoldMessenger.of(context);
      final navigator = Navigator.of(context);

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '${product['name'] ?? 'Listing'} created successfully.',
          ),
        ),
      );

      navigator.pop(product);
    } on DioException catch (e) {
      if (!mounted) return;

      String message = 'Could not create listing.';

      final data = e.response?.data;

      if (data is Map) {
        if (data['detail'] != null) {
          message = data['detail'].toString();
        } else {
          message = data.entries
              .map(
                (entry) =>
                    '${entry.key}: ${entry.value}',
              )
              .join('\n');
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
        ),
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
          _isLoading = false;
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create listing'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'What are you selling?',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),

                const SizedBox(height: 20),

                // ----------------------------------------------------------------
                // PRODUCT / SERVICE
                // ----------------------------------------------------------------

                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment<bool>(
                      value: true,
                      label: Text('Product'),
                      icon: Icon(
                        Icons.shopping_bag_outlined,
                      ),
                    ),
                    ButtonSegment<bool>(
                      value: false,
                      label: Text('Service'),
                      icon: Icon(
                        Icons.handyman_outlined,
                      ),
                    ),
                  ],
                  selected: {_isProduct},
                  onSelectionChanged: _isLoading
                      ? null
                      : (selection) {
                          setState(() {
                            _isProduct = selection.first;
                          });
                        },
                ),

                const SizedBox(height: 24),

                // ----------------------------------------------------------------
                // NAME
                // ----------------------------------------------------------------

                TextFormField(
                  controller: _nameController,
                  enabled: !_isLoading,
                  textCapitalization:
                      TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    hintText: 'e.g. Nike Air Force 1',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null ||
                        value.trim().isEmpty) {
                      return 'Enter a name';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // ----------------------------------------------------------------
                // CATEGORY
                // ----------------------------------------------------------------

                DropdownButtonFormField<int>(
                  initialValue: _categoryId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                  ),
                  items: _categories
                      .map(
                        (category) => DropdownMenuItem<int>(
                          value: category.id,
                          child: Text(category.name),
                        ),
                      )
                      .toList(),
                  onChanged: _isLoading
                      ? null
                      : (value) {
                          setState(() {
                            _categoryId = value;
                          });
                        },
                ),

                const SizedBox(height: 16),

                // ----------------------------------------------------------------
                // DESCRIPTION
                // ----------------------------------------------------------------

                TextFormField(
                  controller: _descriptionController,
                  enabled: !_isLoading,
                  maxLines: 4,
                  textCapitalization:
                      TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText:
                        'Tell students about your listing...',
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 16),

                // ----------------------------------------------------------------
                // IMAGES
                // ----------------------------------------------------------------

                Text(
                  'Listing images',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),

                const SizedBox(height: 8),

                Text(
                  'Add up to 5 images. Each image must be under 2 MB.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall,
                ),

                const SizedBox(height: 12),

                if (_selectedImages.isNotEmpty)
                  SizedBox(
                    height: 110,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _selectedImages.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final image = _selectedImages[index];

                        return Stack(
                          children: [
                            ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(12),
                              child: Image.file(
                                File(image.path),
                                width: 110,
                                height: 110,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: Material(
                                color: Colors.black54,
                                shape:
                                    const CircleBorder(),
                                child: InkWell(
                                  customBorder:
                                      const CircleBorder(),
                                  onTap: _isLoading
                                      ? null
                                      : () =>
                                          _removeImage(index),
                                  child: const Padding(
                                    padding:
                                        EdgeInsets.all(5),
                                    child: Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),

                if (_selectedImages.isNotEmpty)
                  const SizedBox(height: 12),

                OutlinedButton.icon(
                  onPressed:
                      _isLoading ? null : _pickImages,
                  icon: const Icon(
                    Icons.add_photo_alternate_outlined,
                  ),
                  label: Text(
                    _selectedImages.length >= 5
                        ? 'Maximum images added'
                        : 'Add images '
                            '(${_selectedImages.length}/5)',
                  ),
                ),

                const SizedBox(height: 16),

                // ----------------------------------------------------------------
                // PRICE
                // ----------------------------------------------------------------

                TextFormField(
                  controller: _priceController,
                  enabled: !_isLoading,
                  keyboardType:
                      const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Price',
                    hintText:
                        'Leave empty if price is negotiable',
                    prefixText: '₦ ',
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 12),

                // ----------------------------------------------------------------
                // AVAILABLE
                // ----------------------------------------------------------------

                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Available'),
                  subtitle: const Text(
                    'Students can currently buy/book this listing.',
                  ),
                  value: _isAvailable,
                  onChanged: _isLoading
                      ? null
                      : (value) {
                          setState(() {
                            _isAvailable = value;
                          });
                        },
                ),

                // ----------------------------------------------------------------
                // PRIVATE
                // ----------------------------------------------------------------

                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Private listing'),
                  subtitle: const Text(
                    'Only you can see this listing.',
                  ),
                  value: _isPrivate,
                  onChanged: _isLoading
                      ? null
                      : (value) {
                          setState(() {
                            _isPrivate = value;
                          });
                        },
                ),

                const SizedBox(height: 24),

                // ----------------------------------------------------------------
                // CREATE BUTTON
                // ----------------------------------------------------------------

                SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    onPressed:
                        _isLoading ? null : _createListing,
                    icon: const Icon(
                      Icons.add_business,
                    ),
                    label: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Create listing'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// CATEGORY MODEL
// -----------------------------------------------------------------------------

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