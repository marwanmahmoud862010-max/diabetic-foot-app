import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'storage_service.dart';
import 'language_service.dart';
import 'widgets/dark_mode_toggle.dart';

class PhotoScreen extends StatefulWidget {
  const PhotoScreen({super.key});

  @override
  State<PhotoScreen> createState() => _PhotoScreenState();
}

class _PhotoScreenState extends State<PhotoScreen> {
  List<Map<String, String>> _rightPhotos = [];
  List<Map<String, String>> _leftPhotos = [];
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
      _loading = false;
    });
  }

  Future<void> _takePhoto(String foot) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.camera, maxWidth: 1024, maxHeight: 1024);
    if (picked == null || !mounted) return;
    final bytes = await picked.readAsBytes();
    if (bytes.lengthInBytes > 4000000) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(LanguageService.t('photo_size_error'))));
      return;
    }
    await StorageService.savePhoto(foot, bytes);
    _loadPhotos();
  }

  Future<void> _pickFromGallery(String foot) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1024, maxHeight: 1024);
    if (picked == null || !mounted) return;
    final bytes = await picked.readAsBytes();
    if (bytes.lengthInBytes > 4000000) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(LanguageService.t('photo_size_error'))));
      return;
    }
    await StorageService.savePhoto(foot, bytes);
    _loadPhotos();
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
              leading: Icon(Icons.camera, color: Theme.of(context).colorScheme.primary),
              title: Text(LanguageService.t('photo_camera')),
              onTap: () { Navigator.pop(context); _takePhoto(foot); },
            ),
            ListTile(
              leading: Icon(Icons.photo_library, color: Theme.of(context).colorScheme.primary),
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
                      _buildFootPhoto(LanguageService.t('photo_right'), 'right', Theme.of(context).colorScheme.primary, _rightPhotos),
                      const SizedBox(height: 16),
                      _buildFootPhoto(LanguageService.t('photo_left'), 'left', Colors.blue, _leftPhotos),
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
                      if (photos.length > 1)
                        Positioned(
                          top: 8, left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                            child: Text('+${photos.length - 1}', style: const TextStyle(color: Colors.white, fontSize: 11)),
                          ),
                        ),
                      Positioned(
                        bottom: 0, left: 0, right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                          color: Colors.black54,
                          child: Text(
                            '${photos.length} ${LanguageService.t('photo_images_count')}',
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
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: const TextStyle(fontSize: 14)),
    );
  }
}
