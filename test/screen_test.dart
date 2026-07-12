import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:diabetic_foot_app/language_service.dart';
import 'package:diabetic_foot_app/history_screen.dart';
import 'package:diabetic_foot_app/tips_screen.dart';
import 'package:diabetic_foot_app/providers/app_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HistoryScreen', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'full_history': [
          'daily_checkup||checkup_ok||2026-07-12',
          'touch_test||touch_cat0||2026-07-11',
        ],
      });
      await LanguageService.load();
    });

    testWidgets('shows history items', (tester) async {
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [prefsProvider.overrideWithValue(prefs)],
          child: const MaterialApp(home: HistoryScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('2026-07-12'), findsOneWidget);
      expect(find.textContaining('2026-07-11'), findsOneWidget);
    });

    testWidgets('shows empty state when no history', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [prefsProvider.overrideWithValue(prefs)],
          child: const MaterialApp(home: HistoryScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('No checkups'), findsOneWidget);
    });
  });

  group('TipsScreen', () {
    testWidgets('shows tips list', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await LanguageService.load();
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [prefsProvider.overrideWithValue(prefs)],
          child: const MaterialApp(home: TipsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ListView), findsOneWidget);
    });
  });
}
