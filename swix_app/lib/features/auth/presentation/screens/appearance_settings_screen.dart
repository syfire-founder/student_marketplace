import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/theme_mode_provider.dart';

class AppearanceSettingsScreen extends ConsumerWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(themeModeProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Appearance')),
      body: ListView(
        children: [
          RadioListTile<ThemeMode>(
            value: ThemeMode.system,
            groupValue: controller.themeMode,
            title: const Text('Use device setting'),
            subtitle: const Text('Follow your phone’s light or dark mode'),
            onChanged: (mode) => _setMode(ref, mode),
          ),
          RadioListTile<ThemeMode>(
            value: ThemeMode.light,
            groupValue: controller.themeMode,
            title: const Text('Light'),
            onChanged: (mode) => _setMode(ref, mode),
          ),
          RadioListTile<ThemeMode>(
            value: ThemeMode.dark,
            groupValue: controller.themeMode,
            title: const Text('Dark'),
            onChanged: (mode) => _setMode(ref, mode),
          ),
        ],
      ),
    );
  }

  Future<void> _setMode(WidgetRef ref, ThemeMode? mode) async {
    if (mode != null) {
      await ref.read(themeModeProvider).setThemeMode(mode);
    }
  }
}
