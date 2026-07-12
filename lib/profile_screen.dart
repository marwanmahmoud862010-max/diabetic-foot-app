import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';
import 'language_service.dart';
import 'route_transition.dart';

class ProfileScreen extends StatefulWidget {
  final Map<String, String>? existingData;
  const ProfileScreen({super.key, this.existingData});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final nameController = TextEditingController();
  final ageController = TextEditingController();
  final diabetesController = TextEditingController();
  final doctorPhoneController = TextEditingController();
  final phoneController = TextEditingController();
  String selectedType = 'type_2';
  String? _photoData;
  bool get _isEditing => widget.existingData != null;

  @override
  void initState() {
    super.initState();
    _loadSavedData();
  }

  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _photoData = prefs.getString('profile_photo');
      phoneController.text = prefs.getString('phone') ?? '';
      doctorPhoneController.text = prefs.getString('doctor_phone') ?? '';
    });
    if (widget.existingData != null) {
      final d = widget.existingData!;
      phoneController.text = d['phone'] ?? '';
      nameController.text = d['name'] ?? '';
      ageController.text = d['age'] ?? '';
      diabetesController.text = d['diabetes_years'] ?? '';
      selectedType = d['diabetes_type'] ?? 'type_2';
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    ageController.dispose();
    diabetesController.dispose();
    doctorPhoneController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, maxWidth: 512, maxHeight: 512);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() => _photoData = base64Encode(bytes));
    }
  }

  void _showPhotoPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                LanguageService.t('profile_photo'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.camera, color: Colors.teal),
              title: Text(LanguageService.t('camera')),
              onTap: () { Navigator.pop(context); _pickPhoto(ImageSource.camera); },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.teal),
              title: Text(LanguageService.t('gallery')),
              onTap: () { Navigator.pop(context); _pickPhoto(ImageSource.gallery); },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? LanguageService.t('edit_profile') : LanguageService.t('setup_profile_title')),
        centerTitle: true,
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.teal.shade50,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: GestureDetector(
                onTap: _showPhotoPicker,
                child: Stack(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.teal,
                        shape: BoxShape.circle,
                        image: _photoData != null
                            ? DecorationImage(
                                image: MemoryImage(base64Decode(_photoData!)),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: _photoData == null
                          ? const Icon(Icons.person, color: Colors.white, size: 56)
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt, color: Colors.teal, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: _showPhotoPicker,
                child: Text(
                  LanguageService.t('change_photo'),
                  style: const TextStyle(color: Colors.teal),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildField(LanguageService.t('phone_label'),
                LanguageService.t('phone_hint'), phoneController, Icons.phone),
            const SizedBox(height: 16),
            _buildField(LanguageService.t('name_label'),
                LanguageService.t('name_hint'), nameController, Icons.person),
            const SizedBox(height: 16),
            _buildField(LanguageService.t('age_label'),
                LanguageService.t('age_hint'), ageController, Icons.cake,
                isNumber: true),
            const SizedBox(height: 16),
            _buildField(LanguageService.t('diabetes_years_label'),
                LanguageService.t('diabetes_years_hint'), diabetesController,
                Icons.calendar_today, isNumber: true),
            const SizedBox(height: 16),
            _buildField(LanguageService.t('doctor_phone'),
                LanguageService.t('doctor_phone_hint'), doctorPhoneController,
                Icons.phone),
            const SizedBox(height: 16),
            Text(LanguageService.t('diabetes_type_label'),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedType,
                  isExpanded: true,
                  items: [
                    DropdownMenuItem(value: 'type_1', child: Text(LanguageService.t('type_1'))),
                    DropdownMenuItem(value: 'type_2', child: Text(LanguageService.t('type_2'))),
                    DropdownMenuItem(value: 'gestational', child: Text(LanguageService.t('gestational'))),
                  ],
                  onChanged: (val) => setState(() => selectedType = val!),
                ),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(_isEditing ? LanguageService.t('save_changes') : LanguageService.t('setup_profile_btn'),
                  style: const TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(String label, String hint, TextEditingController controller,
      IconData icon, {bool isNumber = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: Colors.teal),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LanguageService.t('enter_name_error'))),
      );
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('phone', phoneController.text);
    await prefs.setString('name', nameController.text);
    await prefs.setString('age', ageController.text);
    await prefs.setString('diabetes_years', diabetesController.text);
    await prefs.setString('diabetes_type', selectedType);
    await prefs.setString('doctor_phone', doctorPhoneController.text);
    if (_photoData != null) {
      await prefs.setString('profile_photo', _photoData!);
    }
    await prefs.setBool('profile_done', true);

    if (mounted) {
      if (_isEditing) {
        Navigator.pop(context);
      } else {
        pushReplacementPage(context, const HomeScreen());
      }
    }
  }
}
