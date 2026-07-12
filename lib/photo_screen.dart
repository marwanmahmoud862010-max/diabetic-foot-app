import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:http/http.dart' as http;
import 'storage_service.dart';
import 'language_service.dart';
import 'api_config.dart';
import 'doctor_avatar.dart';

enum _ViewMode { camera, history, compare }

class PhotoScreen extends StatefulWidget {
  const PhotoScreen({super.key});

  @override
  State<PhotoScreen> createState() => _PhotoScreenState();
}

class _PhotoScreenState extends State<PhotoScreen> {
  final picker = ImagePicker();
  List<Map<String, String>> rightPhotos = [];
  List<Map<String, String>> leftPhotos = [];
  List<Map<String, String>> allPhotos = [];
  _ViewMode _viewMode = _ViewMode.camera;

  bool _analyzing = false;
  final Set<String> _selectedForCompare = {};
  String _compareText = '';
  bool _comparing = false;

  @override
  void initState() {
    super.initState();
    _loadPhotos();
    LanguageService.currentLang.addListener(_onLangChanged);
  }

  void _onLangChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    LanguageService.currentLang.removeListener(_onLangChanged);
    super.dispose();
  }

  Future<void> _loadPhotos() async {
    rightPhotos = await StorageService.getPhotos('right');
    leftPhotos = await StorageService.getPhotos('left');
    allPhotos = await StorageService.getAllPhotos();
    if (mounted) setState(() {});
  }

  String _t(String key) => LanguageService.t(key);
  String _lang() => LanguageService.currentLang.value;

  Future<void> _getImage(String foot, ImageSource source) async {
    final file = await picker.pickImage(source: source, maxWidth: 1024);
    if (file == null) return;
    await StorageService.savePhotoPath(foot, file.path);
    await _loadPhotos();
    _analyzeImage(file.path);
  }

  Map<String, dynamic> _analyzePixels(String path) {
    final bytes = File(path).readAsBytesSync();
    final picture = img.decodeImage(bytes);
    if (picture == null) return {'symptoms': <String>[], 'risk': 'unknown', 'summary': 'تعذر تحليل الصورة'};

    int total = 0;
    int redPixels = 0, bluePixels = 0, darkPixels = 0, palePixels = 0;
    double totalR = 0, totalG = 0, totalB = 0;
    final int step = (picture.width * picture.height > 200000) ? 6 : 3;

    for (int y = 0; y < picture.height; y += step) {
      for (int x = 0; x < picture.width; x += step) {
        final p = picture.getPixel(x, y);
        final r = p.r.toInt(), g = p.g.toInt(), b = p.b.toInt();
        total++;
        totalR += r; totalG += g; totalB += b;

        if (r > 150 && r > g * 1.25 && r > b * 1.25) redPixels++;
        if (b > 100 && b > r * 1.15 && b > g * 1.15) bluePixels++;
        if (r < 70 && g < 70 && b < 70) darkPixels++;
        final avg = (r + g + b) / 3;
        final diff = [r, g, b].reduce((a, b) => a > b ? a : b) - [r, g, b].reduce((a, b) => a < b ? a : b);
        if (avg > 190 && diff < 25) palePixels++;
      }
    }

    if (total == 0) return {'symptoms': <String>[], 'risk': 'unknown', 'summary': 'لا توجد pixels للتحليل'};

    final rRatio = redPixels / total * 100;
    final bRatio = bluePixels / total * 100;
    final dRatio = darkPixels / total * 100;
    final pRatio = palePixels / total * 100;
    final avgR = totalR / total, avgG = totalG / total, avgB = totalB / total;

    final isAr = _lang() == 'ar';
    final isFr = _lang() == 'fr';

    final symptoms = <String>[];
    int maxSev = 0;

    String sev(double val, double t1, double t2, String mild, String mod, String sevStr) {
      if (val > t2) { maxSev = maxSev > 2 ? maxSev : 2; return sevStr; }
      if (val > t1) { maxSev = maxSev > 1 ? maxSev : 1; return mod; }
      return mild;
    }

    if (rRatio > 4) {
      final s = sev(rRatio, 7, 12, 'خفيف', 'متوسط', 'شديد');
      symptoms.add(isAr ? '• احمرار: $s (${rRatio.toStringAsFixed(1)}%)'
          : isFr ? '• Rougeur: $s (${rRatio.toStringAsFixed(1)}%)'
          : '• Redness: $s (${rRatio.toStringAsFixed(1)}%)');
    }
    if (bRatio > 2.5) {
      final s = sev(bRatio, 5, 9, 'خفيف', 'متوسط', 'شديد');
      symptoms.add(isAr ? '• ازرقاق: $s (${bRatio.toStringAsFixed(1)}%)'
          : isFr ? '• Bleuissement: $s (${bRatio.toStringAsFixed(1)}%)'
          : '• Blueness: $s (${bRatio.toStringAsFixed(1)}%)');
    }
    if (dRatio > 1.5) {
      symptoms.add(isAr ? '• بقع داكنة (احتمال جروح): ${dRatio.toStringAsFixed(1)}%'
          : isFr ? '• Taches sombres (plaies possibles): ${dRatio.toStringAsFixed(1)}%'
          : '• Dark spots (possible wounds): ${dRatio.toStringAsFixed(1)}%');
      maxSev = maxSev > 2 ? maxSev : 2;
    }
    if (pRatio > 15) {
      symptoms.add(isAr ? '• شحوب: ${pRatio.toStringAsFixed(1)}%'
          : isFr ? '• Pâleur: ${pRatio.toStringAsFixed(1)}%'
          : '• Paleness: ${pRatio.toStringAsFixed(1)}%');
      if (pRatio > 30) maxSev = maxSev > 1 ? maxSev : 1;
    }

    String risk;
    if (maxSev >= 2 || dRatio > 3 || bRatio > 8) {
      risk = isAr ? 'مرتفع' : isFr ? 'élevé' : 'high';
    } else if (maxSev >= 1 || rRatio > 8 || bluePixels > 0) {
      risk = isAr ? 'متوسط' : isFr ? 'moyen' : 'medium';
    } else {
      risk = isAr ? 'منخفض' : isFr ? 'faible' : 'low';
    }

    String summary;
    if (symptoms.isEmpty) {
      summary = isAr ? 'الفحص مطمئن. لون الجلد طبيعي.'
          : isFr ? 'L\'examen est rassurant. Couleur de peau normale.'
          : 'Checkup is reassuring. Normal skin color.';
      risk = isAr ? 'منخفض' : isFr ? 'faible' : 'low';
    } else {
      summary = isAr ? 'تم اكتشاف بعض الأعراض. يرجى المتابعة.'
          : isFr ? 'Des symptômes ont été détectés. Veuillez suivre.'
          : 'Some symptoms detected. Please monitor.';
    }

    return {
      'symptoms': symptoms,
      'risk': risk,
      'summary': summary,
      'avgR': avgR, 'avgG': avgG, 'avgB': avgB,
      'rRatio': rRatio, 'bRatio': bRatio, 'dRatio': dRatio, 'pRatio': pRatio,
    };
  }

  String _buildAnalysisText(Map<String, dynamic> result) {
    final isAr = _lang() == 'ar';
    final isFr = _lang() == 'fr';
    final symptoms = result['symptoms'] as List<String>;
    final risk = result['risk'] as String;
    final summary = result['summary'] as String;

    final buf = StringBuffer();
    buf.writeln(isAr ? '🤖 تحليل AI:' : isFr ? '🤖 Analyse AI:' : '🤖 AI Analysis:');
    buf.writeln('');
    buf.writeln(summary);
    if (symptoms.isNotEmpty) {
      buf.writeln('');
      buf.writeln(isAr ? 'الأعراض المكتشفة:' : isFr ? 'Symptômes détectés:' : 'Detected symptoms:');
      for (final s in symptoms) {
        buf.writeln(s);
      }
    }
    buf.writeln('');
    buf.writeln(isAr ? 'مستوى الخطورة: $risk' : isFr ? 'Niveau de risque: $risk' : 'Risk level: $risk');
    return buf.toString();
  }

  String _buildRiskLabel(String risk) {
    final isAr = _lang() == 'ar';
    final isFr = _lang() == 'fr';
    if (risk.contains('مرتفع') || risk.contains('élevé') || risk == 'high') return isAr ? 'مرتفع' : isFr ? 'élevé' : 'high';
    if (risk.contains('متوسط') || risk.contains('moyen') || risk == 'medium') return isAr ? 'متوسط' : isFr ? 'moyen' : 'medium';
    return isAr ? 'منخفض' : isFr ? 'faible' : 'low';
  }

  Color _riskColor(String risk) {
    if (risk.contains('مرتفع') || risk.contains('élevé') || risk == 'high') return Colors.red;
    if (risk.contains('متوسط') || risk.contains('moyen') || risk == 'medium') return Colors.orange;
    return Colors.green;
  }

  String _langPrompt(String textAr, String textEn, String textFr) {
    return _lang() == 'ar' ? textAr : _lang() == 'fr' ? textFr : textEn;
  }

  String _geminiPrompt() {
    return _langPrompt(
      'أنت خبير في تحليل القدم السكري. حلل صورة القدم هذه. ارجع JSON فقط:\n'
      '{"symptoms":[{"name":"اسم العرض","severity":"خفيف/متوسط/شديد"}],"riskLevel":"منخفض/متوسط/مرتفع","summary":"ملخص"}',
      'You are a diabetic foot expert. Analyze this foot image. Return ONLY valid JSON:\n'
      '{"symptoms":[{"name":"symptom","severity":"mild/moderate/severe"}],"riskLevel":"low/medium/high","summary":"summary"}',
      'Vous êtes un expert du pied diabétique. Analysez cette image. Retournez JSON uniquement:\n'
      '{"symptoms":[{"name":"symptôme","severity":"léger/modéré/sévère"}],"riskLevel":"faible/moyen/élevé","summary":"résumé"}');
  }

  String _geminiComparePrompt() {
    return _langPrompt(
      'قارن بين صورتي القدم. الأولى أقدم والثانية أحدث. ارجع JSON:\n'
      '{"assessment":"تحسن/لا تغيير/سوء","details":"شرح","specificChanges":[{"symptom":"اسم","change":"قل/زاد/ثابت","detail":"توضيح"}]}',
      'Compare these two foot images. Image 1 is older, Image 2 is newer. Return JSON:\n'
      '{"assessment":"improved/no_change/worsened","details":"explain","specificChanges":[{"symptom":"name","change":"decreased/increased/stable","detail":"detail"}]}',
      'Comparez ces deux images du pied. Image 1 plus ancienne, Image 2 plus récente. Retournez JSON:\n'
      '{"assessment":"amélioré/pas_de_changement/aggravé","details":"explication","specificChanges":[{"symptom":"nom","change":"diminué/augmenté/stable","detail":"description"}]}');
  }

  Future<Map<String, dynamic>?> _callGemini(List<Map<String, dynamic>> parts) async {
    try {
      final key = ApiConfig.geminiApiKey;
      if (key.isEmpty || key == 'YOUR_GEMINI_API_KEY') return null;
      final response = await http.post(
        Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$key'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [{'parts': parts}],
          'generationConfig': {'temperature': 0.2, 'maxOutputTokens': 1024}
        }),
      );
      if (response.statusCode != 200) return null;
      final body = jsonDecode(response.body);
      final text = body['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '';
      final cleaned = text.replaceAll(RegExp(r'```json|```'), '').trim();
      return jsonDecode(cleaned) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  String _geminiAnalysisText(Map<String, dynamic> data) {
    final symptoms = data['symptoms'] as List? ?? [];
    final risk = data['riskLevel'] as String? ?? 'unknown';
    final summary = data['summary'] as String? ?? '';
    final buf = StringBuffer();
    buf.writeln(_langPrompt('🤖 تحليل Gemini AI:', '🤖 Gemini AI Analysis:', '🤖 Analyse Gemini AI:'));
    buf.writeln('');
    buf.writeln(summary);
    if (symptoms.isNotEmpty) {
      buf.writeln('');
      buf.writeln(_langPrompt('الأعراض المكتشفة:', 'Detected symptoms:', 'Symptômes détectés:'));
      for (final s in symptoms) {
        final name = s['name'] ?? '';
        final sev = s['severity'] ?? '';
        buf.writeln('• $name${sev.toString().isNotEmpty ? ' ($sev)' : ''}');
      }
    }
    buf.writeln('');
    buf.writeln(_langPrompt('مستوى الخطورة: $risk', 'Risk level: $risk', 'Niveau de risque: $risk'));
    return buf.toString();
  }

  String _geminiCompareText(Map<String, dynamic> data) {
    final assessment = data['assessment'] as String? ?? '';
    final details = data['details'] as String? ?? '';
    final changes = data['specificChanges'] as List? ?? [];
    final buf = StringBuffer();
    if (assessment.contains('تحسن') || assessment.contains('improved') || assessment.contains('amélior')) {
      buf.writeln('✅ $_langPrompt("تحسن", "Improved", "Amélioration")');
    } else if (assessment.contains('سوء') || assessment.contains('worsened') || assessment.contains('aggrav')) {
      buf.writeln('🔴 $_langPrompt("سوء", "Worsened", "Aggravation")');
    } else {
      buf.writeln('⚪ $_langPrompt("لا تغيير", "No change", "Pas de changement")');
    }
    buf.writeln('');
    buf.writeln(details);
    if (changes.isNotEmpty) {
      buf.writeln('');
      for (final c in changes) {
        final sym = c['symptom'] ?? '';
        final ch = c['change'] ?? '';
        final det = c['detail'] ?? '';
        buf.writeln('• $sym: $ch${det.toString().isNotEmpty ? ' ($det)' : ''}');
      }
    }
    return buf.toString();
  }

  Future<void> _analyzeImage(String path) async {
    setState(() { _analyzing = true; });
    try {
      final file = File(path);
      if (!await file.exists()) throw Exception('File not found');

      // Try Gemini first
      final bytes = await file.readAsBytes();
      final b64 = base64Encode(bytes);
      final geminiResult = await _callGemini([
        {'text': _geminiPrompt()},
        {'inline_data': {'mime_type': 'image/jpeg', 'data': b64}}
      ]);

      String analysisText;
      String risk;

      if (geminiResult != null) {
        analysisText = _geminiAnalysisText(geminiResult);
        risk = _buildRiskLabel((geminiResult['riskLevel'] as String?) ?? 'medium');
      } else {
        // Fallback to local analysis
        final result = _analyzePixels(path);
        analysisText = _buildAnalysisText(result);
        risk = _buildRiskLabel(result['risk'] as String);
      }

      await StorageService.saveAnalysis(path, analysisText, risk);
      await _loadPhotos();
    } catch (e) {
      debugPrint('Analysis error: $e');
    }
    if (mounted) setState(() { _analyzing = false; });
  }

  Future<void> _compareImages() async {
    final paths = _selectedForCompare.toList();
    if (paths.length != 2) return;

    setState(() { _comparing = true; _compareText = ''; });

    try {
      // Try Gemini first
      final parts = <Map<String, dynamic>>[
        {'text': _geminiComparePrompt()},
      ];
      for (final p in paths) {
        final file = File(p);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          parts.add({'inline_data': {'mime_type': 'image/jpeg', 'data': base64Encode(bytes)}});
        }
      }
      final geminiResult = await _callGemini(parts);

      if (geminiResult != null) {
        _compareText = _geminiCompareText(geminiResult);
      } else {
        // Fallback to local comparison
        final r1 = _analyzePixels(paths[0]);
        final r2 = _analyzePixels(paths[1]);
        final isAr = _lang() == 'ar';
        final isFr = _lang() == 'fr';

        final rRatio1 = r1['rRatio'] as double, rRatio2 = r2['rRatio'] as double;
        final bRatio1 = r1['bRatio'] as double, bRatio2 = r2['bRatio'] as double;
        final dRatio1 = r1['dRatio'] as double, dRatio2 = r2['dRatio'] as double;
        final pRatio1 = r1['pRatio'] as double, pRatio2 = r2['pRatio'] as double;

        final improvements = <String>[];
        final worsening = <String>[];
        final noChange = <String>[];

        void compare(String nameAr, String nameEn, String nameFr, double oldV, double newV, double threshold) {
          final name = isAr ? nameAr : isFr ? nameFr : nameEn;
          final diff = newV - oldV;
          if (diff < -threshold) {
            improvements.add(isAr ? '$name: قل من ${oldV.toStringAsFixed(1)}% إلى ${newV.toStringAsFixed(1)}%'
                : isFr ? '$name: diminué de ${oldV.toStringAsFixed(1)}% à ${newV.toStringAsFixed(1)}%'
                : '$name: decreased from ${oldV.toStringAsFixed(1)}% to ${newV.toStringAsFixed(1)}%');
          } else if (diff > threshold) {
            worsening.add(isAr ? '$name: زاد من ${oldV.toStringAsFixed(1)}% إلى ${newV.toStringAsFixed(1)}%'
                : isFr ? '$name: augmenté de ${oldV.toStringAsFixed(1)}% à ${newV.toStringAsFixed(1)}%'
                : '$name: increased from ${oldV.toStringAsFixed(1)}% to ${newV.toStringAsFixed(1)}%');
          } else {
            noChange.add(isAr ? '$name: مستقر' : isFr ? '$name: stable' : '$name: stable');
          }
        }

        compare('احمرار', 'Redness', 'Rougeur', rRatio1, rRatio2, 1.5);
        compare('ازرقاق', 'Blueness', 'Bleuissement', bRatio1, bRatio2, 1.0);
        compare('بقع داكنة', 'Dark spots', 'Taches sombres', dRatio1, dRatio2, 0.8);
        compare('شحوب', 'Paleness', 'Pâleur', pRatio1, pRatio2, 3);

        String assessment;
        if (improvements.length > worsening.length) {
          assessment = isAr ? '✅ تحسن' : isFr ? '✅ Amélioration' : '✅ Improved';
        } else if (worsening.length > improvements.length) {
          assessment = isAr ? '🔴 سوء' : isFr ? '🔴 Aggravation' : '🔴 Worsened';
        } else {
          assessment = isAr ? '⚪ لا تغيير يذكر' : isFr ? '⚪ Aucun changement significatif' : '⚪ No significant change';
        }

        final buf = StringBuffer();
        buf.writeln(assessment);
        buf.writeln('');
        if (improvements.isNotEmpty) {
          buf.writeln(isAr ? 'تحسن:' : isFr ? 'Améliorations:' : 'Improvements:');
          for (final s in improvements) { buf.writeln('  $s'); }
          buf.writeln('');
        }
        if (worsening.isNotEmpty) {
          buf.writeln(isAr ? 'سوء:' : isFr ? 'Aggravations:' : 'Worsening:');
          for (final s in worsening) { buf.writeln('  $s'); }
          buf.writeln('');
        }
        if (noChange.length == 4) {
          buf.writeln(isAr ? 'كل المؤشرات مستقرة - لا تغيير يذكر بين الصورتين.'
              : isFr ? 'Tous les indicateurs sont stables - aucun changement significatif.'
              : 'All indicators stable - no significant change.');
        }

        if (mounted) setState(() { _compareText = buf.toString(); _comparing = false; });
      }
    } catch (e) {
      if (mounted) setState(() { _compareText = 'Error: $e'; _comparing = false; });
    }
  }

  void _showPhotoOptions(String foot) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(foot == 'right' ? _t('photo_right') : _t('photo_left'),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.teal),
                title: Text(_t('photo_camera')),
                onTap: () { Navigator.pop(context); _getImage(foot, ImageSource.camera); },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.teal),
                title: Text(_t('photo_gallery')),
                onTap: () { Navigator.pop(context); _getImage(foot, ImageSource.gallery); },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F3),
      appBar: AppBar(
        title: Text(_t('foot_photo')),
        centerTitle: true,
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_viewMode == _ViewMode.camera ? Icons.history : Icons.camera_alt),
            tooltip: 'تغيير العرض',
            onPressed: () {
              setState(() {
                _viewMode = _viewMode == _ViewMode.camera ? _ViewMode.history : _ViewMode.camera;
              });
            },
          ),
        ],
      ),
      body: Directionality(
        textDirection: LanguageService.isRTL ? TextDirection.rtl : TextDirection.ltr,
        child: _viewMode == _ViewMode.history
            ? _buildHistoryView()
            : _viewMode == _ViewMode.compare
                ? _buildCompareView()
                : _buildCameraView(),
      ),
    );
  }

  Widget _buildCameraView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        DoctorChatBubble(
          message: _t('photo_intro'),
          isRTL: LanguageService.isRTL,
        ),
        const SizedBox(height: 20),
        _buildFootSection(_t('photo_right'), rightPhotos, 'right', Colors.teal),
        const SizedBox(height: 20),
        _buildFootSection(_t('photo_left'), leftPhotos, 'left', Colors.blue),
        const SizedBox(height: 20),
        Text(_t('photo_look_for'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        _buildWarning(_t('photo_warning1'), Colors.red),
        _buildWarning(_t('photo_warning2'), Colors.orange),
        _buildWarning(_t('photo_warning3'), Colors.brown),
        _buildWarning(_t('photo_warning4'), Colors.amber.shade800),
        _buildWarning(_t('photo_warning5'), Colors.blueGrey),
      ],
    );
  }

  Widget _buildFootSection(String title, List<Map<String, String>> photos, String foot, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            IconButton(
              icon: const Icon(Icons.add_a_photo),
              color: color,
              onPressed: () => _showPhotoOptions(foot),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (photos.isEmpty)
          GestureDetector(
            onTap: () => _showPhotoOptions(foot),
            child: Container(
              height: 150, width: double.infinity,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.camera_alt, color: color, size: 40),
                  const SizedBox(height: 8),
                  Text(_t('photo_tap_to_add'), style: TextStyle(color: color, fontSize: 13)),
                ],
              ),
            ),
          )
        else
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: photos.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final photo = photos[index];
                final risk = _buildRiskLabel(photo['risk'] ?? '');
                return GestureDetector(
                  onTap: () => _showPhotoWithAnalysis(photo),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(
                          File(photo['path']!),
                          width: 120, height: 120, fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            width: 120, height: 120,
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.broken_image, color: Colors.grey),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0, left: 0, right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          color: Colors.black54,
                          child: Text(
                            photo['date']!.length >= 10 ? photo['date']!.substring(0, 10) : '',
                            style: const TextStyle(color: Colors.white, fontSize: 9),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      if (risk.isNotEmpty)
                        Positioned(
                          top: 4, right: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _riskColor(photo['risk'] ?? ''),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              risk.length > 6 ? risk.substring(0, 6) : risk,
                              style: const TextStyle(color: Colors.white, fontSize: 8),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  void _showPhotoWithAnalysis(Map<String, String> photo) {
    final risk = photo['risk'] ?? '';
    final analysis = photo['analysis'] ?? '';
    final path = photo['path'] ?? '';
    final date = photo['date'] ?? '';
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: File(path).existsSync()
                      ? Image.file(File(path), height: 250, width: double.infinity, fit: BoxFit.contain)
                      : SizedBox(height: 150, child: Center(child: Text(_t('photo_unavailable')))),
                ),
                if (_analyzing)
                  Container(
                    height: 250,
                    color: Colors.black45,
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: Colors.white),
                          SizedBox(height: 8),
                          Text('جاري التحليل...', style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                if (date.isNotEmpty)
                  Positioned(
                    bottom: 8, left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(date, style: const TextStyle(color: Colors.white, fontSize: 11)),
                    ),
                  ),
              ],
            ),
            if (analysis.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (risk.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _riskColor(risk),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _lang() == 'ar' ? 'الخطورة: ${_buildRiskLabel(risk)}'
                              : _lang() == 'fr' ? 'Risque: ${_buildRiskLabel(risk)}'
                              : 'Risk: ${_buildRiskLabel(risk)}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Text(analysis, style: const TextStyle(fontSize: 13)),
                      ),
                    ),
                  ],
                ),
              ),
            if (analysis.isEmpty && !_analyzing)
              Padding(
                padding: const EdgeInsets.all(20),
                child: ElevatedButton.icon(
                  onPressed: () { Navigator.pop(ctx); _analyzeImage(path); },
                  icon: Icon(Icons.auto_awesome),
                  label: Text(_lang() == 'ar' ? 'تحليل الصورة' : _lang() == 'fr' ? 'Analyser' : 'Analyze'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(_lang() == 'ar' ? 'إغلاق' : _lang() == 'fr' ? 'Fermer' : 'Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryView() {
    return allPhotos.isEmpty
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.photo_library, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                Text(_lang() == 'ar' ? 'لا توجد صور بعد'
                    : _lang() == 'fr' ? 'Aucune photo pour le moment'
                    : 'No photos yet',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                const SizedBox(height: 8),
                Text(_lang() == 'ar' ? 'صور قدمك الأولي'
                    : _lang() == 'fr' ? 'Prenez votre première photo'
                    : 'Take your first photo',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
              ],
            ),
          )
        : Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Text('${_lang() == 'ar' ? 'كل الصور' : _lang() == 'fr' ? 'Toutes les photos' : 'All photos'} (${allPhotos.length})',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    if (allPhotos.length >= 2)
                      TextButton.icon(
                        onPressed: () => setState(() => _viewMode = _ViewMode.compare),
                        icon: const Icon(Icons.compare_arrows),
                        label: Text(_lang() == 'ar' ? 'قارن' : _lang() == 'fr' ? 'Comparer' : 'Compare'),
                      ),
                    TextButton.icon(
                      onPressed: _loadPhotos,
                      icon: const Icon(Icons.refresh),
                      label: Text(_lang() == 'ar' ? 'تحديث' : _lang() == 'fr' ? 'Actualiser' : 'Refresh'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, childAspectRatio: 0.85, crossAxisSpacing: 10, mainAxisSpacing: 10,
                  ),
                  itemCount: allPhotos.length,
                  itemBuilder: (context, index) {
                    final photo = allPhotos[index];
                    final risk = photo['risk'] ?? '';
                    final analysis = photo['analysis'] ?? '';
                    return GestureDetector(
                      onTap: () => _showPhotoWithAnalysis(photo),
                      onLongPress: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: Text(_lang() == 'ar' ? 'حذف الصورة؟'
                                : _lang() == 'fr' ? 'Supprimer la photo?'
                                : 'Delete photo?'),
                            content: Text(_lang() == 'ar' ? 'هل تريد حذف هذه الصورة وتحليلها؟'
                                : _lang() == 'fr' ? 'Supprimer cette photo et son analyse?'
                                : 'Delete this photo and its analysis?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false),
                                  child: Text(_lang() == 'ar' ? 'إلغاء' : _lang() == 'fr' ? 'Annuler' : 'Cancel')),
                              TextButton(onPressed: () => Navigator.pop(ctx, true),
                                  child: Text(_lang() == 'ar' ? 'حذف' : _lang() == 'fr' ? 'Supprimer' : 'Delete')),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await StorageService.deletePhoto(photo['path']!);
                          await _loadPhotos();
                        }
                      },
                      child: Card(
                        clipBehavior: Clip.antiAlias, elevation: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: File(photo['path']!).existsSync()
                                        ? Image.file(File(photo['path']!), fit: BoxFit.cover)
                                        : Container(color: Colors.grey.shade200, child: const Icon(Icons.broken_image)),
                                  ),
                                  if (risk.isNotEmpty)
                                    Positioned(
                                      top: 6, right: 6,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: _riskColor(risk),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(risk, style: const TextStyle(color: Colors.white, fontSize: 10)),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(photo['date'] ?? '',
                                      style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                  const SizedBox(height: 4),
                                  Text(
                                    analysis.isNotEmpty
                                        ? (analysis.length > 60 ? '${analysis.substring(0, 60)}...' : analysis)
                                        : (_lang() == 'ar' ? 'لا يوجد تحليل'
                                            : _lang() == 'fr' ? 'Pas d\'analyse' : 'No analysis'),
                                    style: TextStyle(fontSize: 11,
                                        color: analysis.isNotEmpty ? Colors.black87 : Colors.grey),
                                    maxLines: 2, overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
  }

  Widget _buildCompareView() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.teal.shade50,
          child: Row(
            children: [
              const Icon(Icons.compare_arrows, color: Colors.teal),
              const SizedBox(width: 8),
              Text(_lang() == 'ar' ? 'اختار صورتين للمقارنة'
                  : _lang() == 'fr' ? 'Choisissez 2 photos'
                  : 'Select 2 photos to compare',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              if (_selectedForCompare.length == 2)
                ElevatedButton.icon(
                  onPressed: _comparing ? null : _compareImages,
                  icon: _comparing
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.auto_awesome),
                  label: Text(_comparing ? '...'
                      : _lang() == 'ar' ? 'قارن'
                      : _lang() == 'fr' ? 'Comparer' : 'Compare'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                ),
            ],
          ),
        ),
        if (_compareText.isNotEmpty)
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.analytics, color: Colors.teal),
                    const SizedBox(width: 8),
                    Text(_lang() == 'ar' ? 'نتيجة المقارنة'
                        : _lang() == 'fr' ? 'Résultat'
                        : 'Comparison result',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const Spacer(),
                    TextButton(
                      onPressed: () => setState(() { _compareText = ''; _selectedForCompare.clear(); }),
                      child: Text(_lang() == 'ar' ? 'مسح' : _lang() == 'fr' ? 'Effacer' : 'Clear'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(_compareText, style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
        Expanded(
          child: allPhotos.isEmpty
              ? Center(child: Text(_lang() == 'ar' ? 'لا توجد صور'
                  : _lang() == 'fr' ? 'Aucune photo' : 'No photos'))
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3, childAspectRatio: 0.9, crossAxisSpacing: 8, mainAxisSpacing: 8,
                  ),
                  itemCount: allPhotos.length,
                  itemBuilder: (context, index) {
                    final photo = allPhotos[index];
                    final path = photo['path']!;
                    final selected = _selectedForCompare.contains(path);
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          if (selected) {
                            _selectedForCompare.remove(path);
                          } else if (_selectedForCompare.length < 2) {
                            _selectedForCompare.add(path);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(_lang() == 'ar' ? 'اختار صورتين فقط'
                                  : _lang() == 'fr' ? 'Choisissez 2 photos seulement'
                                  : 'Select only 2 photos')),
                            );
                          }
                        });
                      },
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: File(path).existsSync()
                                ? Image.file(File(path), fit: BoxFit.cover, width: double.infinity, height: double.infinity)
                                : Container(color: Colors.grey.shade200, child: const Icon(Icons.broken_image)),
                          ),
                          if (selected)
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.teal.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.teal, width: 3),
                                ),
                                child: Center(
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(color: Colors.teal, shape: BoxShape.circle),
                                    child: Text(
                                      '${_selectedForCompare.toList().indexOf(path) + 1}',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          Positioned(
                            bottom: 0, left: 0, right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              color: Colors.black54,
                              child: Text(
                                photo['date'] ?? '',
                                style: const TextStyle(color: Colors.white, fontSize: 9),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildWarning(String text, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber, color: color, size: 20),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }
}
