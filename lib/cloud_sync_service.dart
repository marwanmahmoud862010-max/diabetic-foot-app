import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class CloudSyncService {
  static FirebaseFirestore? _firestore;

  static Future<void> _ensureInit() async {
    try {
      if (_firestore == null) {
        await Firebase.initializeApp();
        _firestore = FirebaseFirestore.instance;
      }
    } catch (_) {}
  }

  static String? get _uid {
    try {
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      return null;
    }
  }

  static Future<void> syncProfileToCloud() async {
    try {
      await _ensureInit();
      final uid = _uid;
      if (uid == null || _firestore == null) return;
      final prefs = await SharedPreferences.getInstance();
      final keys = [
        'name', 'age', 'diabetes_years', 'diabetes_type', 'phone',
        'doctor_phone', 'profile_photo', 'profile_done',
        'risk_level', 'risk_title',
      ];
      final data = <String, dynamic>{};
      for (final k in keys) {
        final v = prefs.get(k);
        if (v != null) data[k] = v;
      }
      await _firestore!.collection('users').doc(uid).set({'profile': data}, SetOptions(merge: true));
    } catch (_) {}
  }

  static Future<void> syncHistoryToCloud() async {
    try {
      await _ensureInit();
      final uid = _uid;
      if (uid == null || _firestore == null) return;
      final prefs = await SharedPreferences.getInstance();
      final history = prefs.getStringList('full_history') ?? [];
      await _firestore!.collection('users').doc(uid).set({'history': history}, SetOptions(merge: true));
    } catch (_) {}
  }

  static Future<void> syncPhotosToCloud() async {
    try {
      await _ensureInit();
      final uid = _uid;
      if (uid == null || _firestore == null) return;
      final prefs = await SharedPreferences.getInstance();
      final rightIds = prefs.getStringList('photos_right') ?? [];
      final leftIds = prefs.getStringList('photos_left') ?? [];
      final photoUrls = <String, String>{};
      final photoDates = <String, String>{};
      for (final id in [...rightIds, ...leftIds]) {
        final url = prefs.getString('photo_url_$id') ?? '';
        final date = prefs.getString('photo_date_$id') ?? '';
        if (url.isNotEmpty) photoUrls[id] = url;
        if (date.isNotEmpty) photoDates[id] = date;
      }
      await _firestore!.collection('users').doc(uid).set({
        'photos_right': rightIds,
        'photos_left': leftIds,
        'photo_urls': photoUrls,
        'photo_dates': photoDates,
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  static Future<void> syncAll() async {
    await syncProfileToCloud();
    await syncHistoryToCloud();
    await syncPhotosToCloud();
  }

  static Future<bool> restoreFromCloud() async {
    try {
      await _ensureInit();
      final uid = _uid;
      if (uid == null || _firestore == null) return false;
      final doc = await _firestore!.collection('users').doc(uid).get();
      if (!doc.exists) return false;
      final data = doc.data()!;
      final prefs = await SharedPreferences.getInstance();
      bool restored = false;

      if (data.containsKey('profile')) {
        final profile = data['profile'] as Map<String, dynamic>;
        for (final entry in profile.entries) {
          final v = entry.value;
          if (v is String) {
            if (!prefs.containsKey(entry.key)) {
              await prefs.setString(entry.key, v);
              restored = true;
            }
          } else if (v is int) {
            if (!prefs.containsKey(entry.key)) {
              await prefs.setInt(entry.key, v);
              restored = true;
            }
          } else if (v is bool) {
            if (!prefs.containsKey(entry.key)) {
              await prefs.setBool(entry.key, v);
              restored = true;
            }
          }
        }
      }

      if (data.containsKey('history')) {
        final history = (data['history'] as List).cast<String>();
        if ((prefs.getStringList('full_history') ?? []).isEmpty && history.isNotEmpty) {
          await prefs.setStringList('full_history', history);
          restored = true;
        }
      }

      if (data.containsKey('photos_right')) {
        final rightIds = (data['photos_right'] as List).cast<String>();
        final leftIds = (data['photos_left'] as List).cast<String>();
        if ((prefs.getStringList('photos_right') ?? []).isEmpty && rightIds.isNotEmpty) {
          await prefs.setStringList('photos_right', rightIds);
          restored = true;
        }
        if ((prefs.getStringList('photos_left') ?? []).isEmpty && leftIds.isNotEmpty) {
          await prefs.setStringList('photos_left', leftIds);
          restored = true;
        }
      }

      if (data.containsKey('photo_urls')) {
        final urls = data['photo_urls'] as Map<String, dynamic>;
        for (final entry in urls.entries) {
          if (!prefs.containsKey('photo_url_${entry.key}')) {
            await prefs.setString('photo_url_${entry.key}', entry.value as String);
          }
        }
      }

      return restored;
    } catch (_) {
      return false;
    }
  }
}
