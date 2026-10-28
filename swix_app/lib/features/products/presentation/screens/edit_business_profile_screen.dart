import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/services/token_storage.dart';

class EditBusinessProfileScreen extends StatefulWidget {
  const EditBusinessProfileScreen({super.key, required this.business});

  final Map<String, dynamic> business;

  @override
  State<EditBusinessProfileScreen> createState() =>
      _EditBusinessProfileScreenState();
}

class _EditBusinessProfileScreenState extends State<EditBusinessProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  XFile? _logo;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.business['name']?.toString() ?? '',
    );
    _descriptionController = TextEditingController(
      text: widget.business['description']?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _chooseLogo() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (image != null && mounted) setState(() => _logo = image);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final token = await const TokenStorage().getToken();
      if (token == null || token.isEmpty) {
        throw Exception('Please log in again.');
      }
      final data = FormData.fromMap({
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        if (_logo != null)
          'logo': await MultipartFile.fromFile(
            _logo!.path,
            filename: _logo!.name,
          ),
      });
      await Dio().patch(
        '${ApiClient.baseUrl}/businessprofiles/${widget.business['id']}/',
        data: data,
        options: Options(headers: {'Authorization': 'Token $token'}),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on DioException catch (error) {
      if (!mounted) return;
      final detail = error.response?.data;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            detail is Map && detail['detail'] != null
                ? detail['detail'].toString()
                : 'Could not save business changes.',
          ),
        ),
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
    final existingLogo = widget.business['logo']?.toString();
    ImageProvider? logoProvider;
    if (_logo != null) {
      logoProvider = FileImage(File(_logo!.path));
    } else if (existingLogo != null && existingLogo.isNotEmpty) {
      logoProvider = CachedNetworkImageProvider(existingLogo);
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Edit business profile')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Center(
                child: CircleAvatar(
                  radius: 48,
                  backgroundImage: logoProvider,
                  child: logoProvider == null
                      ? const Icon(Icons.storefront_outlined, size: 40)
                      : null,
                ),
              ),
              Center(
                child: TextButton.icon(
                  onPressed: _saving ? null : _chooseLogo,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: const Text('Change business logo'),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                enabled: !_saving,
                decoration: const InputDecoration(
                  labelText: 'Business name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a business name'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                enabled: !_saving,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Business description',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
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
