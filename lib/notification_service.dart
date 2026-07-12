import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'language_service.dart';

class NotificationService {
  static final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  static const _reminderKey = 'daily_reminder_enabled';

  static Future<void> init() async {
    if (kIsWeb) return;
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await flutterLocalNotificationsPlugin.initialize(initSettings);
  }

  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_reminderKey) ?? false;
  }

  static Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_reminderKey, enabled);
    if (kIsWeb) return;
    if (enabled) {
      await _scheduleDaily();
    } else {
      await flutterLocalNotificationsPlugin.cancel(0);
    }
  }

  static Future<void> _scheduleDaily() async {
    if (kIsWeb) return;
    final title = LanguageService.t('app_name');
    final body = LanguageService.t('daily_reminder_body');
    final channel = LanguageService.t('daily_checkup');

    await flutterLocalNotificationsPlugin.periodicallyShow(
      0,
      title,
      body,
      RepeatInterval.daily,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_checkup',
          channel,
          channelDescription: channel,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  static Future<void> showNotificationNow(String title, String body) async {
    if (kIsWeb) return;
    await flutterLocalNotificationsPlugin.show(
      1, title, body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'general', LanguageService.t('app_name'),
          channelDescription: LanguageService.t('daily_checkup'),
          importance: Importance.defaultImportance,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }
}
