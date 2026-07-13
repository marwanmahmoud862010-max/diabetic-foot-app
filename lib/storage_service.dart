import 'dart:convert';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static final Map<String, String> _analysisStore = {};

  static Future<void> savePhoto(String foot, List<int> bytes, {String? existingId}) async {
    final prefs = await SharedPreferences.getInstance();
    final id = existingId ?? DateTime.now().millisecondsSinceEpoch.toString();
    final base64Str = base64Encode(bytes);
    await prefs.setString('photo_data_$id', base64Str);
    try {
      final ref = _storage.ref('photos/$foot/$id.jpg');
      await ref.putData(Uint8List.fromList(bytes));
      final url = await ref.getDownloadURL();
      await prefs.setString('photo_url_$id', url);
    } catch (_) {}
    if (existingId == null) {
      final key = 'photos_$foot';
      final list = prefs.getStringList(key) ?? [];
      list.add(id);
      await prefs.setStringList(key, list);
    }
  }

  static Future<List<Map<String, String>>> getPhotos(String foot) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'photos_$foot';
    final ids = prefs.getStringList(key) ?? [];
    final list = <Map<String, String>>[];
    for (final id in ids) {
      final url = prefs.getString('photo_url_$id') ?? '';
      final data = prefs.getString('photo_data_$id') ?? '';
      final date = prefs.getString('photo_date_$id') ?? '';
      final analysis = _analysisStore[id] ?? (prefs.getString('photo_analysis_$id') ?? '');
      final risk = prefs.getString('photo_risk_$id') ?? '';
      list.add({'id': id, 'url': url, 'data': data, 'date': date, 'analysis': analysis, 'risk': risk});
    }
    return list.reversed.toList();
  }

  static Future<void> saveAnalysis(String id, String analysis, String risk) async {
    final prefs = await SharedPreferences.getInstance();
    _analysisStore[id] = analysis;
    await prefs.setString('photo_analysis_$id', analysis);
    await prefs.setString('photo_risk_$id', risk);
    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    await prefs.setString('photo_date_$id', dateStr);
  }

  static Future<void> deletePhoto(String id) async {
    final prefs = await SharedPreferences.getInstance();
    for (final foot in ['right', 'left']) {
      final key = 'photos_$foot';
      final list = prefs.getStringList(key) ?? [];
      if (list.contains(id)) {
        list.remove(id);
        await prefs.setStringList(key, list);
        break;
      }
    }
    final url = prefs.getString('photo_url_$id');
    if (url != null && url.isNotEmpty) {
      try {
        final ref = _storage.refFromURL(url);
        await ref.delete();
      } catch (_) {}
    }
    await prefs.remove('photo_url_$id');
    await prefs.remove('photo_data_$id');
    await prefs.remove('photo_analysis_$id');
    await prefs.remove('photo_risk_$id');
    await prefs.remove('photo_date_$id');
    _analysisStore.remove(id);
  }

  static Future<List<Map<String, String>>> getAllPhotos() async {
    final right = await getPhotos('right');
    final left = await getPhotos('left');
    final all = [...right, ...left];
    all.sort((a, b) => (b['date'] ?? '').compareTo(a['date'] ?? ''));
    return all;
  }

  static Future<void> _addToHistory(String type, String result) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('full_history') ?? [];
    final now = DateTime.now();
    final date =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    list.add('$type||$result||$date');
    await prefs.setStringList('full_history', list);
  }

  static Future<List<Map<String, String>>> getFullHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('full_history') ?? [];
    return raw.map((e) {
      final parts = e.split('||');
      return {
        'type': parts.isNotEmpty ? parts[0] : '',
        'result': parts.length > 1 ? parts[1] : '',
        'date': parts.length > 2 ? parts[2] : '',
      };
    }).toList();
  }

  static Future<Map<String, dynamic>> getLastCheckup() async {
    final history = await getFullHistory();
    final entries = history.where((e) => e['type'] == 'daily_checkup').toList();
    if (entries.isEmpty) return {'result': ''};
    return {'result': entries.last['result'] ?? ''};
  }

  static Future<Map<String, dynamic>> getLastTouchTest() async {
    final history = await getFullHistory();
    final entries = history.where((e) => e['type'] == 'touch_test').toList();
    if (entries.isEmpty) return {'result': ''};
    return {'result': entries.last['result'] ?? ''};
  }

  static Future<Map<String, dynamic>> getLastTemperature() async {
    final history = await getFullHistory();
    final entries = history.where((e) => e['type'] == 'temperature').toList();
    if (entries.isEmpty) return {'result': ''};
    return {'result': entries.last['result'] ?? ''};
  }

  static Future<Map<String, dynamic>> getLastRiskAssessment() async {
    final prefs = await SharedPreferences.getInstance();
    final level = prefs.getInt('risk_level') ?? 0;
    final title = prefs.getString('risk_title') ?? '';
    return {'level': level, 'title': title};
  }

  static Future<void> saveCheckup(String result) async {
    await _addToHistory('daily_checkup', result);
  }

  static Future<void> saveTouchTest(String result) async {
    await _addToHistory('touch_test', result);
  }

  static Future<void> saveTemperature(String result) async {
    await _addToHistory('temperature', result);
  }

  static Future<void> saveRiskAssessment(int level, String titleKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('risk_level', level);
    await prefs.setString('risk_title', titleKey);
    await _addToHistory('risk_assessment', titleKey);
  }
}
