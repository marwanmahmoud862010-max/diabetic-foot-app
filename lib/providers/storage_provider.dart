import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../storage_service.dart';

final sharedPrefsProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Override in ProviderScope');
});

final fullHistoryProvider = FutureProvider<List<Map<String, String>>>((ref) async {
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

final lastRiskAssessmentProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  return StorageService.getLastRiskAssessment();
});

final invalidateHistoryProvider = Provider<void>((ref) {
  ref.invalidate(fullHistoryProvider);
  ref.invalidate(lastCheckupProvider);
  ref.invalidate(lastTouchTestProvider);
  ref.invalidate(lastTemperatureProvider);
  ref.invalidate(lastRiskAssessmentProvider);
});
