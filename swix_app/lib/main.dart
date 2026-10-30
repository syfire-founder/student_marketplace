import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_provider.dart';
import 'features/auth/presentation/screens/splash_screen.dart';

void main() {
  runApp(const ProviderScope(child: BluuBaseApp()));
}

class BluuBaseApp extends ConsumerWidget {
  const BluuBaseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider).themeMode;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'BluuBase',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: const SplashScreen(),
    );
  }
}
