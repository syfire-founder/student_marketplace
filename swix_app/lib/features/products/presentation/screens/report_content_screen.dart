import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/services/token_storage.dart';

class ReportContentScreen extends StatefulWidget {
  const ReportContentScreen({
    super.key,
    required this.reportType,
    required this.contentId,
    required this.contentName,
  });

  final String reportType;
  final int contentId;
  final String contentName;

  @override
  State<ReportContentScreen> createState() => _ReportContentScreenState();
}

class _ReportContentScreenState extends State<ReportContentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _sending = true);
    try {
      final token = await const TokenStorage().getToken();
      if (token == null || token.isEmpty) {
        throw Exception('Please log in to send a report.');
      }
      await Dio().post(
        '${ApiClient.baseUrl}/reports/',
        data: {
          'report_type': widget.reportType,
          if (widget.reportType == 'product') 'product': widget.contentId,
          if (widget.reportType == 'business') 'business': widget.contentId,
          'reason': _reasonController.text.trim(),
        },
        options: Options(headers: {'Authorization': 'Token $token'}),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on DioException catch (error) {
      if (!mounted) return;
      final data = error.response?.data;
      final message = data is Map
          ? data['detail']?.toString() ??
                data.entries.map((entry) => '${entry.key}: ${entry.value}').join('\n')
          : 'Could not send your report. Please try again.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final typeName = widget.reportType == 'product' ? 'listing' : 'business';
    return Scaffold(
      appBar: AppBar(title: Text('Report $typeName')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'Tell us why you are reporting “${widget.contentName}”.',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              const Text(
                'Your report will be sent privately to the BluuBase administrators for review.',
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _reasonController,
                enabled: !_sending,
                autofocus: true,
                minLines: 4,
                maxLines: 8,
                maxLength: 1000,
                decoration: const InputDecoration(
                  labelText: 'Reason for reporting',
                  hintText: 'Explain what is wrong with this listing or business.',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.trim().length < 5
                    ? 'Please give a little more detail.'
                    : null,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _sending ? null : _submit,
                icon: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.flag_outlined),
                label: Text(_sending ? 'Sending report…' : 'Send report'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
