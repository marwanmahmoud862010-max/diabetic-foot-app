import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'storage_service.dart';
import 'language_service.dart';
import 'api_config.dart';
import 'widgets/dark_mode_toggle.dart';
import 'connectivity_service.dart';

class PhotoScreen extends StatefulWidget {
  const PhotoScreen({super.key});

  @override
  State<PhotoScreen> createState() => _PhotoScreenState();
}

class _PhotoScreenState extends State<PhotoScreen> {
  List<Map<String, String>> _rightPhotos = [];
  List<Map<String, String>> _leftPhotos = [];
  Uint8List? _rightLastBytes;
  Uint8List? _leftLastBytes;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPhotos();
  }

  Future<void> _loadPhotos() async {
    final right = await StorageService.getPhotos('right');
    final left = await StorageService.getPhotos('left');
    if (!mounted) return;
    setState(() {
      _rightPhotos = right;
      _leftPhotos = left;
      _rightLastBytes = right.isNotEmpty && right.first['data']!.isNotEmpty
          ? base64Decode(right.first['data']!)
          : null;
      _leftLastBytes = left.isNotEmpty && left.first['data']!.isNotEmpty
          ? base64Decode(left.first['data']!)
          : null;
      _loading = false;
    });
  }

  Future<void> _takePhoto(String foot) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.camera, maxWidth: 1024, maxHeight: 1024);
    if (picked == null || !mounted) return;
    final bytes = await picked.readAsBytes();
    await StorageService.savePhoto(foot, bytes);
    if (foot == 'right') {
      _rightLastBytes = Uint8List.fromList(bytes);
    } else {
      _leftLastBytes = Uint8List.fromList(bytes);
    }
    _loadPhotos();
  }

  Future<void> _pickFromGallery(String foot) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1024, maxHeight: 1024);
    if (picked == null || !mounted) return;
    final bytes = await picked.readAsBytes();
    await StorageService.savePhoto(foot, bytes);
    if (foot == 'right') {
      _rightLastBytes = Uint8List.fromList(bytes);
    } else {
      _leftLastBytes = Uint8List.fromList(bytes);
    }
    _loadPhotos();
  }

  Future<void> _analyzeLatest() async {
    final rightBytes = _rightLastBytes;
    final leftBytes = _leftLastBytes;
    if (rightBytes == null && leftBytes == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(LanguageService.t('photo_no_photo'))));
      }
      return;
    }
    if (!await ConnectivityService.check()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(LanguageService.t('offline_desc'))));
      }
      return;
    }

    String? rightResultText;
    bool? rightIsRisk;

    String? leftResultText;
    bool? leftIsRisk;

    bool rightDone = false;
    bool leftDone = false;

    void Function(void Function())? dlgUpdate;

    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: StatefulBuilder(
            builder: (ctx, setDlgState) {
              dlgUpdate = setDlgState;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!rightDone || !leftDone) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ],
                    if (rightResultText != null)
                      _buildResultBox(
                        LanguageService.t('photo_right'),
                        rightResultText!,
                        rightIsRisk!,
                      ),
                    if (rightResultText != null)
                      const SizedBox(height: 12),
                    if (leftResultText != null)
                      _buildResultBox(
                        LanguageService.t('photo_left'),
                        leftResultText!,
                        leftIsRisk!,
                      ),
                    if (rightDone && leftDone)
                      Padding(
                        padding: const EdgeInsets.only(top: 20),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () { Navigator.pop(ctx); _loadPhotos(); },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: Text(LanguageService.t('ok'), style: const TextStyle(fontSize: 16)),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );

    if (rightBytes == null) rightDone = true;
    if (leftBytes == null) leftDone = true;

    // Analyze right foot
    if (rightBytes != null) {
      final r = await _runSingleAnalysis(rightBytes);
      if (mounted) {
        if (r != null) {
          final photos = _rightPhotos;
          if (photos.isNotEmpty) {
            await StorageService.saveAnalysis(photos.first['id'] ?? '', r.analysis, r.isRisk ? 'high' : 'low');
          }
          dlgUpdate?.call(() {
            rightResultText = r.analysis;
            rightIsRisk = r.isRisk;
            rightDone = true;
          });
        } else {
          dlgUpdate?.call(() {
            rightResultText = LanguageService.t('network_error');
            rightIsRisk = false;
            rightDone = true;
          });
        }
      }
    }

    // Analyze left foot
    if (leftBytes != null) {
      final r = await _runSingleAnalysis(leftBytes);
      if (mounted) {
        if (r != null) {
          final photos = _leftPhotos;
          if (photos.isNotEmpty) {
            await StorageService.saveAnalysis(photos.first['id'] ?? '', r.analysis, r.isRisk ? 'high' : 'low');
          }
          dlgUpdate?.call(() {
            leftResultText = r.analysis;
            leftIsRisk = r.isRisk;
            leftDone = true;
          });
        } else {
          dlgUpdate?.call(() {
            leftResultText = LanguageService.t('network_error');
            leftIsRisk = false;
            leftDone = true;
          });
        }
      }
    }

    if (mounted && rightDone && leftDone) {
      dlgUpdate?.call(() {});
    }
  }

  Future<({bool isRisk, String analysis})?> _runSingleAnalysis(List<int> bytes) async {
    if (ApiConfig.groqApiKey.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(LanguageService.t('network_error'))));
      }
      return null;
    }
    for (int attempt = 0; attempt < 2; attempt++) {
      if (attempt > 0) await Future.delayed(const Duration(seconds: 1));
      try {
        final base64Image = base64Encode(bytes);
        final response = await http.post(
          Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
          headers: {
            'Authorization': 'Bearer ${ApiConfig.groqApiKey}',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': 'meta-llama/llama-4-scout-17b-16e-instruct',
            'messages': [
              {
                'role': 'user',
                'content': [
                  {'type': 'text', 'text': LanguageService.t('photo_ai_prompt')},
                  {'type': 'image_url', 'image_url': {'url': 'data:image/jpeg;base64,$base64Image'}},
                ],
              },
            ],
            'max_tokens': 1000,
          }),
        );
        if (!mounted) return null;
        if (response.statusCode != 200) {
          debugPrint('Groq API error ${response.statusCode}: ${response.body}');
          if (attempt == 1) return null;
          continue;
        }
        final data = jsonDecode(response.body);
        final raw = data['choices']?[0]?['message']?['content'] as String? ?? '';
        final isRisk = raw.startsWith('RISK') || raw.startsWith('risk') || raw.startsWith('خطر') || raw.startsWith('RISQUE');
        final analysis = isRisk ? raw.replaceFirst(RegExp(r'^(RISK|risk|خطر|RISQUE)\s*'), '') : raw;
        return (isRisk: isRisk, analysis: analysis);
      } catch (e) {
        if (attempt == 1) {
          debugPrint('_runSingleAnalysis error: $e');
          return null;
        }
      }
    }
    return null;
  }

  Widget _buildResultBox(String footLabel, String analysis, bool isRisk) {
    final bgColor = isRisk ? Colors.red.shade50 : Colors.green.shade50;
    final borderColor = isRisk ? Colors.red : Colors.green;
    final icon = isRisk ? Icons.warning_rounded : Icons.check_circle_rounded;
    final iconColor = isRisk ? Colors.red : Colors.green;
    final label = isRisk ? LanguageService.t('photo_risk_high') : LanguageService.t('photo_risk_low');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 22),
              const SizedBox(width: 8),
              Text(footLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: isRisk ? Colors.red : Colors.green,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(analysis, style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7), height: 1.4)),
        ],
      ),
    );
  }

  void _showPicker(String foot, String title) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            ListTile(
              leading: const Icon(Icons.camera, color: Colors.teal),
              title: Text(LanguageService.t('photo_camera')),
              onTap: () { Navigator.pop(context); _takePhoto(foot); },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.teal),
              title: Text(LanguageService.t('photo_gallery')),
              onTap: () { Navigator.pop(context); _pickFromGallery(foot); },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(LanguageService.t('foot_photo')),
        centerTitle: true,
        actions: [const DarkModeToggle()],
      ),
      body: Directionality(
        textDirection: LanguageService.isRTL ? TextDirection.rtl : TextDirection.ltr,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Stack(
                children: [
                  ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Text(LanguageService.t('photo_intro'), style: const TextStyle(fontSize: 13)),
                      ),
                      const SizedBox(height: 24),
                      _buildFootPhoto(LanguageService.t('photo_right'), 'right', Colors.teal, _rightPhotos),
                      const SizedBox(height: 16),
                      _buildFootPhoto(LanguageService.t('photo_left'), 'left', Colors.blue, _leftPhotos),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: _analyzeLatest,
                          icon: const Icon(Icons.auto_awesome),
                          label: Text(LanguageService.t('photo_analyze_ai')),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(LanguageService.t('photo_look_for'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      _buildWarning(LanguageService.t('photo_warning1')),
                      _buildWarning(LanguageService.t('photo_warning2')),
                      _buildWarning(LanguageService.t('photo_warning3')),
                      _buildWarning(LanguageService.t('photo_warning4')),
                      _buildWarning(LanguageService.t('photo_warning5')),
                    ],
                  ),
                  ],
                ),
            ),
    );
  }

  Widget _buildFootPhoto(String title, String foot, Color color, List<Map<String, String>> photos) {
    final latest = photos.isNotEmpty ? photos.first : <String, String>{};
    final data = latest['data'] ?? '';
    final analysis = latest['analysis'] ?? '';
    final risk = latest['risk'] ?? '';
    final id = latest['id'] ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            if (photos.length > 1)
              TextButton.icon(
                onPressed: () => _showComparison(foot, title, photos),
                icon: const Icon(Icons.compare, size: 18),
                label: Text(LanguageService.t('photo_compare')),
              ),
          ],
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _showPicker(foot, title),
          onLongPress: data.isNotEmpty ? () => _showDeleteDialog(foot, id) : null,
          child: Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: data.isEmpty
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.camera_alt, color: color, size: 40),
                      const SizedBox(height: 8),
                      Text('${LanguageService.t('photo_tap_to_capture')}$title', style: TextStyle(color: color, fontSize: 13)),
                    ],
                  )
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(base64Decode(data), fit: BoxFit.cover),
                      ),
                      Positioned(
                        top: 8, left: 8,
                        child: risk == 'high'
                            ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(12)),
                                child: Text(LanguageService.t('photo_risk_high'), style: const TextStyle(color: Colors.white, fontSize: 11)),
                              )
                            : risk == 'low'
                                ? Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(12)),
                                    child: Text(LanguageService.t('photo_risk_low'), style: const TextStyle(color: Colors.white, fontSize: 11)),
                                  )
                                : const SizedBox(),
                      ),
                      Positioned(
                        bottom: 0, left: 0, right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                          color: Colors.black54,
                          child: Text(
                            analysis.isNotEmpty ? analysis : '${photos.length} ${LanguageService.t('photo_images_count')}',
                            style: const TextStyle(color: Colors.white, fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  void _showComparison(String foot, String title, List<Map<String, String>> photos) {
    if (photos.length < 2) return;
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text('${LanguageService.t('photo_compare')} $title', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            SizedBox(
              height: 300,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: photos.length,
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.all(4),
                  child: Column(
                    children: [
                      Text('${LanguageService.t('photo_image')} ${i + 1}', style: const TextStyle(fontSize: 11)),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Builder(builder: (_) {
                          final data = photos[i]['data'] ?? '';
                          final url = photos[i]['url'] ?? '';
                          return data.isNotEmpty
                              ? Image.memory(base64Decode(data), height: 220, width: 160, fit: BoxFit.cover)
                              : Image.network(url, height: 220, width: 160, fit: BoxFit.cover, errorBuilder: (_, _, _) => const Icon(Icons.broken_image, size: 40));
                        }),
                      ),
                      if ((photos[i]['analysis'] ?? '').isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(photos[i]['analysis']!, style: const TextStyle(fontSize: 10, color: Colors.grey), maxLines: 2),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            TextButton(onPressed: () => Navigator.pop(context), child: Text(LanguageService.t('photo_close'))),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(String foot, String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(LanguageService.t('photo_delete_title')),
        content: Text(LanguageService.t('photo_delete_confirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(LanguageService.t('cancel'))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(LanguageService.t('delete'))),
        ],
      ),
    );
    if (confirmed == true) {
      await StorageService.deletePhoto(id);
      await _loadPhotos();
    }
  }

  Widget _buildWarning(String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: const TextStyle(fontSize: 14)),
    );
  }
}
