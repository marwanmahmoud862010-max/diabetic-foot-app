import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../storage_service.dart';

final prefsProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Override prefsProvider in ProviderScope');
});

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final prefs = ref.read(prefsProvider);
    return prefs.getBool('dark_mode') ?? false ? ThemeMode.dark : ThemeMode.light;
  }

  Future<void> toggle() async {
    final next = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    state = next;
    final prefs = ref.read(prefsProvider);
    await prefs.setBool('dark_mode', next == ThemeMode.dark);
  }
}

final fullHistoryProvider = FutureProvider<List<Map<String, String>>>((ref) {
  return StorageService.getFullHistory();
});

final lastCheckupProvider = FutureProvider<String?>((ref) async {
  final r = await StorageService.getLastCheckup();
  return r['result'] as String?;
});

final lastTouchTestProvider = FutureProvider<String?>((ref) async {
  final r = await StorageService.getLastTouchTest();
  return r['result'] as String?;
});

final lastTemperatureProvider = FutureProvider<String?>((ref) async {
  final r = await StorageService.getLastTemperature();
  return r['result'] as String?;
});

final lastRiskProvider = FutureProvider<Map<String, dynamic>>((ref) {
  return StorageService.getLastRiskAssessment();
});

final profileDataProvider = FutureProvider<Map<String, String>>((ref) async {
  final prefs = ref.read(prefsProvider);
  return {
    'name': prefs.getString('name') ?? '',
    'age': prefs.getString('age') ?? '',
    'diabetes_years': prefs.getString('diabetes_years') ?? '',
    'diabetes_type': prefs.getString('diabetes_type') ?? 'type_2',
    'phone': prefs.getString('phone') ?? '',
  };
});

final profileDoneProvider = FutureProvider<bool>((ref) async {
  final prefs = ref.read(prefsProvider);
  return prefs.getBool('profile_done') ?? false;
});
