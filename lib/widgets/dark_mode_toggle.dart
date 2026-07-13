import 'package:flutter/material.dart';
import '../theme_service.dart';
import '../language_service.dart';

class DarkModeToggle extends StatelessWidget {
  const DarkModeToggle({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, mode, _) {
        final isDark = mode == ThemeMode.dark;
        return IconButton(
          icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
          tooltip: LanguageService.t(isDark ? 'light_mode' : 'dark_mode'),
          onPressed: ThemeService.toggle,
        );
      },
    );
  }
}
