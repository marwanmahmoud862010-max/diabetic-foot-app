import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../storage_service.dart';

final prefsProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Override prefsProvider in ProviderScope');
});

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

final profileDoneProvider = FutureProvider<bool>((ref) async {
  final prefs = ref.read(prefsProvider);
  return prefs.getBool('profile_done') ?? false;
});

