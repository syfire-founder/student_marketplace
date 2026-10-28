import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_state_provider.dart';
import 'authenticated_screen.dart';
import 'login_screen.dart';
import 'admin_reports_screen.dart';
import '../../../../core/services/token_storage.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      ref.read(authControllerProvider.notifier).checkAuthentication();
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      if (!mounted) return;

      if (next.status == AuthStatus.authenticated) {
        _routeAuthenticatedUser();
      }

      if (next.status == AuthStatus.unauthenticated) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    });

    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }

  Future<void> _routeAuthenticatedUser() async {
    final isAdmin = await const TokenStorage().getIsAdmin();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => isAdmin
            ? const AdminReportsScreen()
            : const AuthenticatedScreen(),
      ),
    );
  }
}
