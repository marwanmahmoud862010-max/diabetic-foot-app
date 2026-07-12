import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  static final Connectivity _connectivity = Connectivity();
  static bool _isOnline = true;
  static StreamSubscription<List<ConnectivityResult>>? _subscription;

  static bool get isOnline => _isOnline;

  static Future<bool> check() async {
    final results = await _connectivity.checkConnectivity();
    _isOnline = results.isNotEmpty && !results.every((r) => r == ConnectivityResult.none);
    return _isOnline;
  }

  static void startMonitoring(void Function(bool online) onChanged) {
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      final online = results.isNotEmpty && !results.every((r) => r == ConnectivityResult.none);
      if (online != _isOnline) {
        _isOnline = online;
        onChanged(online);
      }
    });
  }

  static void dispose() {
    _subscription?.cancel();
  }
}
