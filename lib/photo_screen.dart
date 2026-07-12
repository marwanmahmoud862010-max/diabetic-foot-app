import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'storage_service.dart';
import 'language_service.dart';
import 'api_config.dart';

class PhotoScreen extends StatefulWidget {
  const PhotoScreen({super.key});

  @override
  State<PhotoScreen> createState() => _PhotoScreenState();
}

class _PhotoScreenState extends State<PhotoScreen> {
  List<Map<String, String>> _rightPhotos = [];
  List<Map<String, String>> _leftPhotos = [];
  bool _loading = true;
  bool _analyzing = false;

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
      _loading = false;
    });
  }

  Future<void> _takePhoto(String foot) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.camera, maxWidth: 1024, maxHeight: 1024);
    if (picked == null || !mounted) return;
    final bytes = await picked.readAsBytes();
    await StorageService.savePhoto(foot, bytes);
    await _analyzePhoto(bytes, foot);
    await _loadPhotos();
  }

  Future<void> _pickFromGallery(String foot) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1024, maxHeight: 1024);
    if (picked == null || !mounted) return;
    final bytes = await picked.readAsBytes();
    await StorageService.savePhoto(foot, bytes);
    await _analyzePhoto(bytes, foot);
    await _loadPhotos();
  }

  Future<void> _analyzePhoto(List<int> bytes, String foot) async {
    if (!mounted) return;
    setState(() => _analyzing = true);
    try {
      final base64Image = base64Encode(bytes);
      final response = await http.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer ${ApiConfig.groqApiKey}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'llama-3.2-11b-vision-preview',
          'messages': [
            {
              'role': 'user',
              'content': [
                {'type': 'text', 'text': 'Analyze this foot photo. Tell me in Arabic if there is: redness, swelling, wounds, callus, discoloration, or any abnormality. Keep response short (2 lines max). If healthy say "القدم سليمة".'},
                {'type': 'image_url', 'image_url': {'url': 'data:image/jpeg;base64,$base64Image'}},
              ],
            },
          ],
          'max_tokens': 200,
        }),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final analysis = data['choices'][0]['message']['content'] as String;
        final isRisk = analysis.contains('احمرار') || analysis.contains('تورم') || analysis.contains('جرح') || analysis.contains('كالو') || analysis.contains('غير طبيعي') || analysis.contains('مشكلة');
        final photos = foot == 'right' ? _rightPhotos : _leftPhotos;
        if (photos.isNotEmpty) {
          await StorageService.saveAnalysis(photos.first['id'] ?? '', analysis, isRisk ? 'high' : 'low');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(LanguageService.t('network_error'))));
      }
    }
    if (!mounted) return;
    setState(() => _analyzing = false);
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
              title: const Text('كاميرا'),
              onTap: () { Navigator.pop(context); _takePhoto(foot); },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.teal),
              title: const Text('معرض الصور'),
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
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
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
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Text(LanguageService.t('photo_intro'), style: const TextStyle(fontSize: 13)),
                      ),
                      const SizedBox(height: 24),
                      _buildFootPhoto('القدم اليمنى', 'right', Colors.teal, _rightPhotos),
                      const SizedBox(height: 16),
                      _buildFootPhoto('القدم اليسرى', 'left', Colors.blue, _leftPhotos),
                      const SizedBox(height: 24),
                      const Text('إيه اللي تدور عليه؟', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      _buildWarning('🔴 احمرار أو تغيير في اللون'),
                      _buildWarning('🟡 تورم أو انتفاخ'),
                      _buildWarning('⚫ جروح أو بثور'),
                      _buildWarning('🟤 كالو مفرط في نقطة واحدة'),
                      _buildWarning('💧 إفرازات أو رطوبة زيادة'),
                    ],
                  ),
                  if (_analyzing)
                    Container(
                      color: Colors.black54,
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: Colors.white),
                            SizedBox(height: 12),
                            Text('جاري تحليل الصورة...', style: TextStyle(color: Colors.white, fontSize: 16)),
                          ],
                        ),
                      ),
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
                label: const Text('مقارنة'),
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
                      Text('اضغط لتصوير $title', style: TextStyle(color: color, fontSize: 13)),
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
                                child: const Text('⚠️ يحتاج متابعة', style: TextStyle(color: Colors.white, fontSize: 11)),
                              )
                            : risk == 'low'
                                ? Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(12)),
                                    child: const Text('✅ سليم', style: TextStyle(color: Colors.white, fontSize: 11)),
                                  )
                                : const SizedBox(),
                      ),
                      Positioned(
                        bottom: 0, left: 0, right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                          color: Colors.black54,
                          child: Text(
                            analysis.isNotEmpty ? analysis : '${photos.length} صور',
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
              child: Text('مقارنة $title', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                      Text('صورة ${i + 1}', style: const TextStyle(fontSize: 11)),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(base64Decode(photos[i]['data'] ?? ''), height: 220, width: 160, fit: BoxFit.cover),
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
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق')),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(String foot, String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف الصورة؟'),
        content: const Text('هل تريد حذف هذه الصورة؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف')),
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
