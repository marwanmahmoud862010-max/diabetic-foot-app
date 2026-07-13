import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'language_service.dart';

class NotificationService {
  static final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  static const _reminderKey = 'daily_reminder_enabled';
  static bool _initialized = false;

  static Future<void> init() async {
    if (kIsWeb) return;
    if (_initialized) return;
    tz_data.initializeTimeZones();
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
    await _requestPermissions();
    await _rescheduleIfEnabled();
    _initialized = true;
  }

  static Future<void> _requestPermissions() async {
    try {
      final android = flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        await android.requestNotificationsPermission();
      }
    } catch (_) {}
  }

  static Future<void> _rescheduleIfEnabled() async {
    if (kIsWeb) return;
    try {
      if (await isEnabled()) {
        await _scheduleAll();
      }
    } catch (_) {}
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
      await _scheduleAll();
    } else {
      await _cancelAll();
    }
  }

  static Future<void> _cancelAll() async {
    for (int i = 0; i < 3; i++) {
      await flutterLocalNotificationsPlugin.cancel(i);
    }
  }

  static Future<void> _scheduleAll() async {
    await _cancelAll();
    final now = DateTime.now();
    final offset = now.timeZoneOffset;

    final targetHours = [9, 15, 21]; // 9AM, 3PM, 9PM

    final bodies = [
      LanguageService.t('reminder_morning'),
      LanguageService.t('reminder_afternoon'),
      LanguageService.t('reminder_evening'),
    ];

    for (int i = 0; i < 3; i++) {
      final localHour = targetHours[i];
      final utcHour = localHour - offset.inHours;
      final utcMinute = -(offset.inMinutes.remainder(60));
      var scheduled = tz.TZDateTime(tz.UTC, now.year, now.month, now.day, utcHour, utcMinute);
      if (scheduled.isBefore(tz.TZDateTime.from(now, tz.UTC))) {
        scheduled = scheduled.add(const Duration(days: 1));
      }
      await _scheduleOne(i, scheduled, bodies[i]);
    }
  }

  static Future<void> _scheduleOne(int id, tz.TZDateTime time, String body) async {
    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      LanguageService.t('app_name'),
      body,
      time,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_checkup',
          LanguageService.t('daily_checkup'),
          channelDescription: LanguageService.t('daily_checkup'),
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static Future<void> showNotificationNow(String title, String body) async {
    if (kIsWeb) return;
    await flutterLocalNotificationsPlugin.show(
      10, title, body,
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
