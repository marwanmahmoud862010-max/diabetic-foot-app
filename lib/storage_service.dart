import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static final Map<String, String> _analysisStore = {};

  // ===== Photo methods =====

  static Future<void> savePhotoPath(String foot, String path) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'photos_$foot';
    final list = (prefs.getStringList(key) ?? [])..add(path);
    await prefs.setStringList(key, list);
  }

  static Future<List<Map<String, String>>> getPhotos(String foot) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'photos_$foot';
    final paths = prefs.getStringList(key) ?? [];
    final list = <Map<String, String>>[];
    for (final path in paths) {
      final date = prefs.getString('${path}_date') ?? '';
      final analysis = _analysisStore[path] ?? (prefs.getString('${path}_analysis') ?? '');
      final risk = prefs.getString('${path}_risk') ?? '';
      list.add({'path': path, 'date': date, 'analysis': analysis, 'risk': risk});
    }
    return list.reversed.toList();
  }

  static Future<void> saveAnalysis(String path, String analysis, String risk) async {
    final prefs = await SharedPreferences.getInstance();
    _analysisStore[path] = analysis;
    await prefs.setString('${path}_analysis', analysis);
    await prefs.setString('${path}_risk', risk);
    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    await prefs.setString('${path}_date', dateStr);
  }

  static Future<void> deletePhoto(String path) async {
    final prefs = await SharedPreferences.getInstance();
    for (final foot in ['right', 'left']) {
      final key = 'photos_$foot';
      final list = prefs.getStringList(key) ?? [];
      if (list.contains(path)) {
        list.remove(path);
        await prefs.setStringList(key, list);
        break;
      }
    }
    await prefs.remove('${path}_analysis');
    await prefs.remove('${path}_risk');
    await prefs.remove('${path}_date');
    _analysisStore.remove(path);
  }

  static Future<List<Map<String, String>>> getAllPhotos() async {
    final right = await getPhotos('right');
    final left = await getPhotos('left');
    final all = [...right, ...left];
    all.sort((a, b) => (b['date'] ?? '').compareTo(a['date'] ?? ''));
    return all;
  }

  // ===== Existing history methods =====

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
