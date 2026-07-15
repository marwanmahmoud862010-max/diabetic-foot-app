import 'package:flutter/material.dart';
import 'storage_service.dart';
import 'language_service.dart';
import 'foot_diagram.dart';
import 'doctor_avatar.dart';
import 'widgets/dark_mode_toggle.dart';

class TouchTestScreen extends StatefulWidget {
  const TouchTestScreen({super.key});

  @override
  State<TouchTestScreen> createState() => _TouchTestScreenState();
}

class _TouchTestScreenState extends State<TouchTestScreen> {
  // المفاتيح ثابتة (يمين/يسار) عشان المنطق، والعرض بيتترجم
  Map<String, bool?> results = {
    'right_1': null,
    'right_3': null,
    'right_5': null,
    'left_1': null,
    'left_3': null,
    'left_5': null,
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
    super.dispose();
  }

  bool _allAnswered() => results.values.every((v) => v != null);

  void _showResult() async {
    int missed = results.values.where((v) => v == false).length;
    String categoryKey;
    String adviceKey;
    Color color;

    if (missed == 0) {
      categoryKey = 'touch_cat0';
      adviceKey = 'touch_advice0';
      color = Colors.green;
    } else if (missed <= 1) {
      categoryKey = 'touch_cat1';
      adviceKey = 'touch_advice1';
      color = Colors.orange;
    } else {
      categoryKey = 'touch_cat2';
      adviceKey = 'touch_advice2';
      color = Colors.red;
    }

    // بنخزّن الكود بس (saveTouchTest بتضيف للسجل لوحدها)
    await StorageService.saveTouchTest(categoryKey);

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
            LanguageService.t(categoryKey),
            textAlign: TextAlign.center,
            style: TextStyle(color: color, fontSize: 16),
          ),
          content: Text(
            LanguageService.t(adviceKey),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(LanguageService.t('touch_title')),
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
              message: LanguageService.t('touch_intro'),
              isRTL: LanguageService.isRTL,
            ),
            _buildFootSection(LanguageService.t('right_foot'), 'right'),
            const SizedBox(height: 20),
            _buildFootSection(LanguageService.t('left_foot'), 'left'),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _allAnswered() ? _showResult : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(LanguageService.t('see_result'),
                  style: const TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFootSection(String title, String foot) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        _buildTouchPoint('${foot}_1', LanguageService.t('toe_1'), foot),
        _buildTouchPoint('${foot}_3', LanguageService.t('toe_3'), foot),
        _buildTouchPoint('${foot}_5', LanguageService.t('toe_5'), foot),
      ],
    );
  }

  Widget _buildTouchPoint(String key, String label, String footSide) {
    final toeNumber = int.parse(key.split('_').last);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label, style: const TextStyle(fontSize: 14)),
              ),
              const SizedBox(width: 12),
              FootDiagram(
                highlightedToe: toeNumber,
                size: 48,
                showLabels: false,
                footSide: footSide,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: () => setState(() => results[key] = true),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: results[key] == true
                        ? Colors.green.shade100
                        : Colors.white,
                      border: Border.all(
                          color: results[key] == true
                              ? Colors.green
                              : Theme.of(context).colorScheme.outline),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(LanguageService.t('felt_it'),
                      style: TextStyle(
                        color: results[key] == true
                            ? Colors.green.shade800
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      )),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => setState(() => results[key] = false),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: results[key] == false
                        ? Colors.red.shade100
                        : Theme.of(context).colorScheme.surface,
                    border: Border.all(
                        color: results[key] == false
                            ? Colors.red
                            : Theme.of(context).colorScheme.outline),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(LanguageService.t('not_felt'),
                      style: TextStyle(
                        color: results[key] == false
                            ? Colors.red.shade800
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      )),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}