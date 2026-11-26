import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/services/token_storage.dart';

class SchoolSelectionScreen extends StatefulWidget {
  const SchoolSelectionScreen({required this.onCompleted, super.key});

  final VoidCallback onCompleted;

  @override
  State<SchoolSelectionScreen> createState() => _SchoolSelectionScreenState();
}

class _SchoolSelectionScreenState extends State<SchoolSelectionScreen> {
  List<_School> _schools = const [];
  int? _selectedSchoolId;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSchools();
  }

  Future<void> _loadSchools() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await Dio().get('${ApiClient.baseUrl}/schools/');
      final data = response.data;
      final items = data is Map
          ? data['results'] as List? ?? const []
          : data as List;
      final schools = items
          .map(
            (item) => _School.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList();
      if (!mounted) return;
      setState(() {
        _schools = schools;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Could not load schools. Check your connection and try again.';
      });
    }
  }

  Future<void> _saveSchool() async {
    final schoolId = _selectedSchoolId;
    if (schoolId == null) {
      setState(() => _error = 'Choose your school to continue.');
      return;
    }
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      final token = await const TokenStorage().getToken();
      if (token == null || token.isEmpty) {
        throw Exception('Your session has expired. Please log in again.');
      }
      await Dio().patch(
        '${ApiClient.baseUrl}/profile/',
        data: {'school': schoolId},
        options: Options(headers: {'Authorization': 'Token $token'}),
      );
      if (!mounted) return;
      widget.onCompleted();
    } on DioException catch (error) {
      if (!mounted) return;
      final responseData = error.response?.data;
      final message = responseData is Map
          ? responseData['detail']?.toString() ??
                responseData['school']?.toString()
          : null;
      setState(() {
        _isSaving = false;
        _error = message ?? 'Could not save your school. Please try again.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choose your school')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null && _schools.isEmpty
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _loadSchools,
                          child: const Text('Try again'),
                        ),
                      ],
                    )
                  : _schools.isEmpty
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'No schools are available right now. Please try again later.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _loadSchools,
                          child: const Text('Try again'),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Select your school to continue to BluuBase.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 24),
                        DropdownButtonFormField<int>(
                          initialValue: _selectedSchoolId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'School',
                            border: OutlineInputBorder(),
                          ),
                          items: _schools
                              .map(
                                (school) => DropdownMenuItem(
                                  value: school.id,
                                  child: Text(school.name),
                                ),
                              )
                              .toList(),
                          onChanged: _isSaving
                              ? null
                              : (value) => setState(() {
                                  _selectedSchoolId = value;
                                  _error = null;
                                }),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: _isSaving ? null : _saveSchool,
                          child: _isSaving
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Continue'),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _School {
  const _School({required this.id, required this.name});

  final int id;
  final String name;

  factory _School.fromJson(Map<String, dynamic> json) =>
      _School(id: json['id'] as int, name: json['name'] as String);
}
