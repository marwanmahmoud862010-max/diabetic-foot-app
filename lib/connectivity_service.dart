import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  static final Connectivity _connectivity = Connectivity();

  static Future<bool> check() async {
    final results = await _connectivity.checkConnectivity();
    return results.isNotEmpty && !results.every((r) => r == ConnectivityResult.none);
  }
}
