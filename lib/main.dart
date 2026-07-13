import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_config.dart';
import 'splash_screen.dart';
import 'language_service.dart';
import 'notification_service.dart';
import 'theme_service.dart';
import 'providers/app_providers.dart';
import 'analytics_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();
  await Firebase.initializeApp(
    options: FirebaseOptions(
      apiKey: FirebaseConfig.apiKey,
      authDomain: FirebaseConfig.authDomain,
      projectId: FirebaseConfig.projectId,
      storageBucket: FirebaseConfig.storageBucket,
      messagingSenderId: FirebaseConfig.messagingSenderId,
      appId: FirebaseConfig.appId,
    ),
  );
  await LanguageService.load();
  final prefs = await SharedPreferences.getInstance();
  final darkMode = prefs.getBool('dark_mode') ?? false;
  themeModeNotifier.value = darkMode ? ThemeMode.dark : ThemeMode.light;
  try {
    await NotificationService.init();
  } catch (_) {}
  try {
    await AnalyticsService.init();
  } catch (_) {}
  runApp(
    ProviderScope(
      overrides: [
        prefsProvider.overrideWithValue(prefs),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: LanguageService.currentLang,
      builder: (context, lang, _) {
        return ValueListenableBuilder<ThemeMode>(
          valueListenable: themeModeNotifier,
          builder: (context, mode, _) {
            return MaterialApp(
              title: LanguageService.t('app_name'),
              locale: Locale(lang),
              themeMode: mode,
              theme: ThemeData(
                colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal, brightness: Brightness.light),
                useMaterial3: true,
                appBarTheme: const AppBarTheme(
                  centerTitle: true,
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                ),
              ),
              darkTheme: ThemeData(
                colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal, brightness: Brightness.dark),
                useMaterial3: true,
                appBarTheme: AppBarTheme(
                  centerTitle: true,
                  backgroundColor: Colors.teal.shade800,
                  foregroundColor: Colors.white,
                ),
                dividerTheme: DividerThemeData(
                  color: Colors.grey.shade600,
                  thickness: 1,
                ),
                textTheme: const TextTheme(
                  bodyLarge: TextStyle(fontWeight: FontWeight.w600),
                  bodyMedium: TextStyle(fontWeight: FontWeight.w600),
                  bodySmall: TextStyle(fontWeight: FontWeight.w600),
                  labelLarge: TextStyle(fontWeight: FontWeight.w700),
                  titleMedium: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              home: const SplashScreen(),
            );
          },
        );
      },
    );
  }
}
