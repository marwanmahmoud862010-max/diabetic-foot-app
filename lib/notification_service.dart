import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'language_service.dart';

class NotificationService {
  static final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  static const _reminderKey = 'daily_reminder_enabled';
  static const _morningId = 0;
  static const _afternoonId = 1;
  static const _eveningId = 2;
  static const _nowId = 10;
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
    try {
      await flutterLocalNotificationsPlugin.initialize(initSettings);
    } catch (_) {
      return;
    }
    await _rescheduleIfEnabled();
    _initialized = true;
  }

  static Future<bool> requestPermissions() async {
    if (kIsWeb) return true;
    bool allGranted = true;
    try {
      final android = flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        final granted = await android.requestNotificationsPermission();
        if (granted != true) {
          allGranted = false;
        }
        try {
          await android.requestExactAlarmsPermission();
        } catch (_) {}
      }
    } catch (_) {
      allGranted = false;
    }
    return allGranted;
  }

  static Future<void> _rescheduleIfEnabled() async {
    if (kIsWeb) return;
    if (await isEnabled()) {
      await _scheduleAll();
    }
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
    for (final id in [_morningId, _afternoonId, _eveningId]) {
      await flutterLocalNotificationsPlugin.cancel(id);
    }
  }

  static Future<void> _scheduleAll() async {
    await _cancelAll();
    final now = DateTime.now();
    final location = tz.local;
    final targetHours = [9, 15, 21];
    final bodies = [
      LanguageService.t('reminder_morning'),
      LanguageService.t('reminder_afternoon'),
      LanguageService.t('reminder_evening'),
    ];
    final ids = [_morningId, _afternoonId, _eveningId];
    for (int i = 0; i < 3; i++) {
      var scheduled = tz.TZDateTime(location, now.year, now.month, now.day, targetHours[i]);
      if (scheduled.isBefore(tz.TZDateTime.from(now, location))) {
        scheduled = scheduled.add(const Duration(days: 1));
      }
      await _scheduleOne(ids[i], scheduled, bodies[i]);
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
      _nowId, title, body,
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
