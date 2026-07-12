import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier(ThemeMode.light);

class ThemeService {
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final dark = prefs.getBool('dark_mode') ?? false;
    themeModeNotifier.value = dark ? ThemeMode.dark : ThemeMode.light;
  }

  static Future<void> toggle() async {
    final prefs = await SharedPreferences.getInstance();
    final current = themeModeNotifier.value;
    final newMode = current == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    themeModeNotifier.value = newMode;
    await prefs.setBool('dark_mode', newMode == ThemeMode.dark);
  }

  static bool get isDark => themeModeNotifier.value == ThemeMode.dark;
}
