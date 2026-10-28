import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/presentation/screens/splash_screen.dart';

void main() {
  runApp(const ProviderScope(child: BluuBaseApp()));
}

class BluuBaseApp extends StatelessWidget {
  const BluuBaseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'BluuBase',
      theme: AppTheme.lightTheme,
      home: const SplashScreen(),
    );
  }
}
