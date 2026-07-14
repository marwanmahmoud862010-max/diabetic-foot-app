import 'package:flutter_dotenv/flutter_dotenv.dart';

class FirebaseConfig {
  static String get apiKey => dotenv.env['FIREBASE_API_KEY'] ?? '';
  static String get authDomain => dotenv.env['FIREBASE_AUTH_DOMAIN'] ?? '';
  static String get projectId => dotenv.env['FIREBASE_PROJECT_ID'] ?? '';
  static String get storageBucket => dotenv.env['FIREBASE_STORAGE_BUCKET'] ?? '';
  static String get messagingSenderId => dotenv.env['FIREBASE_MESSAGING_SENDER_ID'] ?? '';
  static String get appId => dotenv.env['FIREBASE_APP_ID'] ?? '';

  static void validate() {
    if (apiKey.isEmpty || projectId.isEmpty || appId.isEmpty) {
      throw StateError(
        'FirebaseConfig is incomplete. Check .env has FIREBASE_API_KEY, FIREBASE_PROJECT_ID, FIREBASE_APP_ID',
      );
    }
  }
}