import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeMode { system, light, dark, amoled }

class ThemeNotifier extends StateNotifier<AppThemeMode> {
  ThemeNotifier() : super(AppThemeMode.system);

  static const _key = 'theme_mode';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_key);
    state = switch (value) {
      'light' => AppThemeMode.light,
      'dark' => AppThemeMode.dark,
      'amoled' => AppThemeMode.amoled,
      _ => AppThemeMode.system,
    };
  }

  Future<void> setTheme(AppThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }

  /// Converts to Flutter's ThemeMode for MaterialApp.
  ThemeMode get flutterThemeMode => switch (state) {
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
        AppThemeMode.amoled => ThemeMode.dark,
        AppThemeMode.system => ThemeMode.system,
      };
}

final themeProvider =
    StateNotifierProvider<ThemeNotifier, AppThemeMode>((ref) => ThemeNotifier());
