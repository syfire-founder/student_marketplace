import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/services/token_storage.dart';

class EditListingScreen extends StatefulWidget {
  const EditListingScreen({super.key, required this.listing});

  final Map<String, dynamic> listing;

  @override
  State<EditListingScreen> createState() => _EditListingScreenState();
}

class _EditListingScreenState extends State<EditListingScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _price;
  late bool _isService;
  late bool _available;
  late bool _private;
  late List<Map<String, dynamic>> _existingImages;
  final Set<int> _removedImageIds = {};
  final List<XFile> _newImages = [];
  final ImagePicker _imagePicker = ImagePicker();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.listing['name']?.toString() ?? '');
    _description = TextEditingController(
      text: widget.listing['description']?.toString() ?? '',
    );
    _price = TextEditingController(text: widget.listing['price']?.toString() ?? '');
    _isService = widget.listing['listing_type'] == 'service';
    _available = widget.listing['is_available'] != false;
    _private = widget.listing['is_private'] == true;
    final rawImages = widget.listing['images'];
    _existingImages = rawImages is List
        ? rawImages
            .whereType<Map>()
            .map((image) => Map<String, dynamic>.from(image))
            .toList()
        : [];
  }

  Future<void> _addImages() async {
    final remaining = 5 - _existingImages.length - _newImages.length;
    if (remaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A listing can have up to 5 photos.')),
      );
      return;
    }
    final picked = await _imagePicker.pickMultiImage(imageQuality: 85);
    if (!mounted || picked.isEmpty) return;
    setState(() => _newImages.addAll(picked.take(remaining)));
    if (picked.length > remaining && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only 5 photos can be added to a listing.')),
      );
    }
  }

  void _removeExistingImage(Map<String, dynamic> image) {
    final id = _toInt(image['id']);
    setState(() {
      _existingImages.remove(image);
      if (id != null) _removedImageIds.add(id);
    });
  }

  void _removeNewImage(XFile image) {
    setState(() => _newImages.remove(image));
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final id = widget.listing['id'];
    setState(() => _saving = true);
    try {
      final token = await const TokenStorage().getToken();
      if (token == null || token.isEmpty) throw Exception('Please log in again.');
      final price = _price.text.trim();
      await Dio().patch(
        '${ApiClient.baseUrl}/products/$id/',
        data: {
          'name': _name.text.trim(),
          'description': _description.text.trim(),
          'price': price.isEmpty ? null : price,
          'listing_type': _isService ? 'service' : 'product',
          'is_available': _available,
          'is_private': _private,
        },
        options: Options(headers: {'Authorization': 'Token $token'}),
      );

      for (final imageId in _removedImageIds.toList()) {
        try {
          await Dio().delete(
            '${ApiClient.baseUrl}/listing-images/$imageId/',
            options: Options(headers: {'Authorization': 'Token $token'}),
          );
        } on DioException catch (error) {
          if (error.response?.statusCode != 404) rethrow;
        }
        _removedImageIds.remove(imageId);
      }

      for (final image in _newImages.toList()) {
        final upload = FormData.fromMap({
          'product': id,
          'image': await MultipartFile.fromFile(
            image.path,
            filename: image.name,
          ),
        });
        await Dio().post(
          '${ApiClient.baseUrl}/listing-images/',
          data: upload,
          options: Options(headers: {'Authorization': 'Token $token'}),
        );
        if (mounted) setState(() => _newImages.remove(image));
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on DioException catch (error) {
      if (!mounted) return;
      final data = error.response?.data;
      final message = data is Map
          ? data['detail']?.toString() ??
                data.entries.map((entry) => '${entry.key}: ${entry.value}').join('\n')
          : 'Could not save listing changes.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit listing')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Product')),
                  ButtonSegment(value: true, label: Text('Service')),
                ],
                selected: {_isService},
                onSelectionChanged: _saving
                    ? null
                    : (selected) => setState(() => _isService = selected.first),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _name,
                enabled: !_saving,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a name'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _description,
                enabled: !_saving,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _price,
                enabled: !_saving,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Price (leave blank for price on request)',
                  prefixText: '₦',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Listing photos (${_existingImages.length + _newImages.length}/5)',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _saving ? null : _addImages,
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: const Text('Add photos'),
                  ),
                ],
              ),
              if (_existingImages.isEmpty && _newImages.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text('No photos added yet.'),
                ),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  ..._existingImages.map(
                    (image) => _PhotoTile(
                      imageUrl: _imageUrl(image['image']),
                      onRemove: _saving ? null : () => _removeExistingImage(image),
                    ),
                  ),
                  ..._newImages.map(
                    (image) => _PhotoTile(
                      localFile: File(image.path),
                      onRemove: _saving ? null : () => _removeNewImage(image),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Available'),
                value: _available,
                onChanged: _saving ? null : (value) => setState(() => _available = value),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Private listing'),
                subtitle: const Text('Hide this listing from other students'),
                value: _private,
                onChanged: _saving ? null : (value) => setState(() => _private = value),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({this.imageUrl, this.localFile, required this.onRemove});

  final String? imageUrl;
  final File? localFile;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    Widget image;
    if (localFile != null) {
      image = Image.file(localFile!, width: 92, height: 92, fit: BoxFit.cover);
    } else if (imageUrl != null) {
      image = CachedNetworkImage(
        imageUrl: imageUrl!,
        width: 92,
        height: 92,
        fit: BoxFit.cover,
        errorWidget: (_, __, ___) => const SizedBox(
          width: 92,
          height: 92,
          child: Icon(Icons.broken_image_outlined),
        ),
      );
    } else {
      image = const SizedBox(
        width: 92,
        height: 92,
        child: Icon(Icons.broken_image_outlined),
      );
    }
    return Stack(
      children: [
        ClipRRect(borderRadius: BorderRadius.circular(10), child: image),
        Positioned(
          top: 2,
          right: 2,
          child: Material(
            color: Colors.black54,
            shape: const CircleBorder(),
            child: IconButton(
              onPressed: onRemove,
              constraints: const BoxConstraints.tightFor(width: 32, height: 32),
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.close, size: 18, color: Colors.white),
              tooltip: 'Remove photo',
            ),
          ),
        ),
      ],
    );
  }
}

int? _toInt(dynamic value) =>
    value is int ? value : int.tryParse(value?.toString() ?? '');

String? _imageUrl(dynamic value) {
  final raw = value?.toString();
  if (raw == null || raw.isEmpty) return null;
  final uri = Uri.tryParse(raw);
  if (uri == null) return null;
  if (uri.hasScheme) {
    if (uri.host == 'localhost' || uri.host == '127.0.0.1') {
      return uri.replace(host: '10.0.2.2').toString();
    }
    return raw;
  }
  return Uri.parse(ApiClient.baseUrl).resolve(raw).toString();
}
