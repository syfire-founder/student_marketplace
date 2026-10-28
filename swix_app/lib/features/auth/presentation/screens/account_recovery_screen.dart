import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../../core/api/api_client.dart';

class AccountRecoveryScreen extends StatefulWidget {
  const AccountRecoveryScreen({super.key});

  @override
  State<AccountRecoveryScreen> createState() => _AccountRecoveryScreenState();
}

class _AccountRecoveryScreenState extends State<AccountRecoveryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _codeRequested = false;
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    if (_email.text.trim().isEmpty || !_email.text.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the email linked to your account.')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      await Dio().post(
        '${ApiClient.baseUrl}/auth/password-reset/',
        data: {'email': _email.text.trim()},
      );
      if (!mounted) return;
      setState(() => _codeRequested = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('If an account uses that email, a reset code was sent.'),
        ),
      );
    } on DioException catch (error) {
      if (!mounted) return;
      final message = error.response?.data is Map
          ? (error.response!.data as Map)['detail']?.toString()
          : null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message ?? 'Could not request a reset code.')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await Dio().post(
        '${ApiClient.baseUrl}/auth/password-reset/confirm/',
        data: {
          'email': _email.text.trim(),
          'code': _code.text.trim(),
          'new_password': _password.text,
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset. Sign in with your new password.')),
      );
      Navigator.of(context).pop();
    } on DioException catch (error) {
      if (!mounted) return;
      final data = error.response?.data;
      final message = data is Map && data['detail'] != null
          ? data['detail'].toString()
          : data is Map && data['new_password'] != null
              ? data['new_password'].toString()
              : 'Could not reset your password. Check your code and try again.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recover account')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Reset your password', style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    const Text('We’ll email you a one-time code to confirm it’s your account.'),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _email,
                      enabled: !_codeRequested && !_loading,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Account email', border: OutlineInputBorder()),
                      validator: (value) => value == null || !value.contains('@')
                          ? 'Enter a valid email'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    if (!_codeRequested)
                      FilledButton(
                        onPressed: _loading ? null : _requestCode,
                        child: _loading ? const CircularProgressIndicator() : const Text('Send recovery code'),
                      ),
                    if (_codeRequested) ...[
                      TextFormField(
                        controller: _code,
                        enabled: !_loading,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        decoration: const InputDecoration(labelText: 'Email code', border: OutlineInputBorder()),
                        validator: (value) => value == null || value.trim().length != 6
                            ? 'Enter the 6-digit code'
                            : null,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _password,
                        enabled: !_loading,
                        obscureText: _obscure,
                        decoration: InputDecoration(
                          labelText: 'New password',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            onPressed: () => setState(() => _obscure = !_obscure),
                            icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                          ),
                        ),
                        validator: (value) => value == null || value.length < 8
                            ? 'Use at least 8 characters'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _confirmPassword,
                        enabled: !_loading,
                        obscureText: _obscure,
                        decoration: const InputDecoration(labelText: 'Confirm new password', border: OutlineInputBorder()),
                        validator: (value) => value != _password.text
                            ? 'Passwords do not match'
                            : null,
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _loading ? null : _resetPassword,
                        child: _loading ? const CircularProgressIndicator() : const Text('Reset password'),
                      ),
                      TextButton(
                        onPressed: _loading ? null : _requestCode,
                        child: const Text('Send another code'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
