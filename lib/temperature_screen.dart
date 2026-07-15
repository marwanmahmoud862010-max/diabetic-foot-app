import 'package:flutter/material.dart';
import 'storage_service.dart';
import 'language_service.dart';
import 'foot_diagram.dart';
import 'doctor_avatar.dart';
import 'widgets/dark_mode_toggle.dart';

class TemperatureScreen extends StatefulWidget {
  const TemperatureScreen({super.key});

  @override
  State<TemperatureScreen> createState() => _TemperatureScreenState();
}

class _TemperatureScreenState extends State<TemperatureScreen> {
  // المفاتيح ثابتة للمنطق، والعرض بيتترجم
  final Map<String, TextEditingController> controllers = {
    'right_heel': TextEditingController(),
    'left_heel': TextEditingController(),
    'right_mid': TextEditingController(),
    'left_mid': TextEditingController(),
    'right_toes': TextEditingController(),
    'left_toes': TextEditingController(),
  };

  @override
  void initState() {
    super.initState();
    LanguageService.currentLang.addListener(_onLangChanged);
  }

  void _onLangChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    LanguageService.currentLang.removeListener(_onLangChanged);
    for (final c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(LanguageService.t('temp_title')),
        centerTitle: true,
        actions: [const DarkModeToggle()],
      ),
      body: Directionality(
        textDirection:
            LanguageService.isRTL ? TextDirection.rtl : TextDirection.ltr,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DoctorChatBubble(
              message: LanguageService.t('temp_intro'),
              isRTL: LanguageService.isRTL,
            ),
            _buildRow(LanguageService.t('temp_heel'), 'heel', 'right_heel', 'left_heel'),
            const SizedBox(height: 12),
            _buildRow(LanguageService.t('temp_mid'), 'mid', 'right_mid', 'left_mid'),
            const SizedBox(height: 12),
            _buildRow(LanguageService.t('temp_toes'), 'toes', 'right_toes', 'left_toes'),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _checkTemperatures,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(LanguageService.t('temp_check'),
                  style: const TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, String region, String rightKey, String leftKey) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${LanguageService.t('temp_right')} — $label',
                  style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 4),
              TextField(
                controller: controllers[rightKey],
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: LanguageService.t('temp_hint'),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${LanguageService.t('temp_left')} — $label',
                  style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 4),
              TextField(
                controller: controllers[leftKey],
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: LanguageService.t('temp_hint'),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        FootDiagram(
          highlightedRegion: region,
          size: 50,
          showLabels: false,
        ),
      ],
    );
  }

  void _checkTemperatures() async {
    bool danger = false;
    List<String> warnings = [];

    final pairs = [
      ['right_heel', 'left_heel', LanguageService.t('temp_heel')],
      ['right_mid', 'left_mid', LanguageService.t('temp_mid')],
      ['right_toes', 'left_toes', LanguageService.t('temp_toes')],
    ];

    for (var pair in pairs) {
      final right = double.tryParse(controllers[pair[0]]!.text);
      final left = double.tryParse(controllers[pair[1]]!.text);
      if (right != null && left != null) {
        final diff = (right - left).abs();
        if (diff > 2.2) {
          danger = true;
          warnings.add(
              '${pair[2]}: ${LanguageService.t('temp_diff')} ${diff.toStringAsFixed(1)} ${LanguageService.t('degree')} ⚠️');
        }
      }
    }

    // بنخزّن الكود عشان يتترجم في الهوم والسجل
    final resultCode = danger ? 'temp_danger' : 'temp_ok';
    await StorageService.saveTemperature(resultCode);

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => Directionality(
        textDirection:
            LanguageService.isRTL ? TextDirection.rtl : TextDirection.ltr,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            danger
                ? LanguageService.t('temp_danger_title')
                : LanguageService.t('temp_ok_title'),
            textAlign: TextAlign.center,
            style: TextStyle(color: danger ? Colors.red : Colors.green),
          ),
          content: Text(
            danger
                ? '${LanguageService.t('temp_danger_intro')}\n${warnings.join('\n')}\n\n${LanguageService.t('temp_danger_advice')}'
                : LanguageService.t('temp_ok_msg'),
            textAlign: TextAlign.center,
          ),
          actions: [
            Center(
              child: TextButton(
                onPressed: () {
                  final nav = Navigator.of(context);
                  nav.pop();
                  nav.pop();
                },
                child: Text(LanguageService.t('ok_btn')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}