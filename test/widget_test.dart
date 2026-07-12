import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:diabetic_foot_app/language_service.dart';
import 'package:diabetic_foot_app/error_handler.dart';
import 'package:diabetic_foot_app/storage_service.dart';
import 'package:diabetic_foot_app/theme_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LanguageService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('has required translation keys', () async {
      await LanguageService.load();
      expect(LanguageService.t('app_name'), isNotEmpty);
      expect(LanguageService.t('daily_checkup'), isNotEmpty);
      expect(LanguageService.t('history'), isNotEmpty);
      expect(LanguageService.t('network_error'), isNotEmpty);
    });

    test('returns unknown key as fallback', () async {
      await LanguageService.load();
      expect(LanguageService.t('nonexistent_key'), equals('nonexistent_key'));
    });

    test('switching language updates currentLang', () async {
      await LanguageService.load();
      await LanguageService.setLang('en');
      expect(LanguageService.currentLang.value, equals('en'));
      expect(LanguageService.isRTL, isFalse);

      await LanguageService.setLang('ar');
      expect(LanguageService.currentLang.value, equals('ar'));
      expect(LanguageService.isRTL, isTrue);
    });
  });

  group('ThemeService', () {
    test('init loads saved theme', () async {
      SharedPreferences.setMockInitialValues({'dark_mode': true});
      await ThemeService.init();
      expect(ThemeService.isDark, isTrue);
    });

    test('toggle switches theme', () async {
      SharedPreferences.setMockInitialValues({'dark_mode': false});
      await ThemeService.init();
      final wasDark = ThemeService.isDark;
      await ThemeService.toggle();
      expect(ThemeService.isDark, isNot(wasDark));
    });
  });

  group('ErrorHandler', () {
    testWidgets('loadingWidget shows CircularProgressIndicator', (tester) async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: ErrorHandler.loadingWidget())));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('loadingWidget shows message', (tester) async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: ErrorHandler.loadingWidget(message: 'Loading...'))));
      expect(find.text('Loading...'), findsOneWidget);
    });

    testWidgets('showSnackBar displays message', (tester) async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(builder: (context) {
        return ElevatedButton(
          onPressed: () => ErrorHandler.showSnackBar(context, 'Test error'),
          child: const Text('Show'),
        );
      }))));
      await tester.tap(find.text('Show'));
      await tester.pump();
      expect(find.text('Test error'), findsOneWidget);
    });
  });

  group('StorageService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('save and get full history', () async {
      await StorageService.saveCheckup('checkup_ok');
      final history = await StorageService.getFullHistory();
      expect(history.length, equals(1));
      expect(history[0]['type'], equals('daily_checkup'));
      expect(history[0]['result'], equals('checkup_ok'));
      expect(history[0]['date'], isNotEmpty);
    });

    test('getLastCheckup returns latest', () async {
      await StorageService.saveCheckup('checkup_ok');
      await StorageService.saveTouchTest('touch_cat0');
      final checkup = await StorageService.getLastCheckup();
      expect(checkup['result'], equals('checkup_ok'));
    });

    test('empty history returns defaults', () async {
      final checkup = await StorageService.getLastCheckup();
      expect(checkup['result'], equals(''));
    });
  });
}
