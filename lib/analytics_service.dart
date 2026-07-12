import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsService {
  static FirebaseAnalytics? _analytics;

  static FirebaseAnalytics get instance {
    _analytics ??= FirebaseAnalytics.instance;
    return _analytics!;
  }

  static Future<void> init() async {
    _analytics = FirebaseAnalytics.instance;
    await _analytics!.setAnalyticsCollectionEnabled(true);
  }

  static Future<void> logScreen(String screenName) async {
    try {
      await instance.logScreenView(screenName: screenName, screenClass: screenName);
    } catch (_) {}
  }

  static Future<void> logEvent(String name, {Map<String, Object>? parameters}) async {
    try {
      await instance.logEvent(name: name, parameters: parameters);
    } catch (_) {}
  }
}
