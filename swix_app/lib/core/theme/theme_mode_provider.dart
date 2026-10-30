import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final themeModeProvider = ChangeNotifierProvider<ThemeModeController>(
  (ref) => ThemeModeController(),
);

class ThemeModeController extends ChangeNotifier {
  static const _storageKey = 'app_theme_mode';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  ThemeModeController() {
    _loadSavedMode();
  }

  Future<void> _loadSavedMode() async {
    try {
      final savedMode = await _storage.read(key: _storageKey);
      _themeMode = switch (savedMode) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
      notifyListeners();
    } catch (_) {
      // Keep following the device setting if preference storage is unavailable.
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final value = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await _storage.write(key: _storageKey, value: value);
  }
}
