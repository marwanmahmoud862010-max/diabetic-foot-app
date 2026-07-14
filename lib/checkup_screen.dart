import 'package:flutter/material.dart';
import 'storage_service.dart';
import 'language_service.dart';
import 'doctor_avatar.dart';
import 'widgets/dark_mode_toggle.dart';

class CheckupScreen extends StatefulWidget {
  const CheckupScreen({super.key});

  @override
  State<CheckupScreen> createState() => _CheckupScreenState();
}

class _CheckupScreenState extends State<CheckupScreen> {
  // بنخزّن كود الإجابة (مش النص) عشان ميتأثرش بتغيير اللغة
  String? q1;
  String? q2;
  String? q3;

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

  bool _allAnswered() => q1 != null && q2 != null && q3 != null;

  Future<void> _showResult() async {
    final bool danger =
        q1 == 'numb_severe' || q2 == 'pain_severe' || q3 == 'answer_yes';

    final String resultCode = danger ? 'checkup_danger' : 'checkup_ok';
    await StorageService.saveCheckup(resultCode);
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (_) => Directionality(
        textDirection:
            LanguageService.isRTL ? TextDirection.rtl : TextDirection.ltr,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Column(
            children: [
              Icon(
                danger ? Icons.warning_amber_rounded : Icons.check_circle,
                color: danger ? Colors.red : Colors.green,
                size: 48,
              ),
              const SizedBox(height: 8),
              Text(
                danger
                    ? LanguageService.t('result_danger_title')
                    : LanguageService.t('result_ok_title'),
                style: TextStyle(
                  color: danger ? Colors.red : Colors.green,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          content: Text(
            danger
                ? LanguageService.t('result_danger_msg')
                : LanguageService.t('result_ok_msg'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, height: 1.5),
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
        title: Text(LanguageService.t('checkup_title')),
        centerTitle: true,
        actions: [const DarkModeToggle()],
      ),
      backgroundColor: const Color(0xFFF0F4F3),
      body: Directionality(
        textDirection:
            LanguageService.isRTL ? TextDirection.rtl : TextDirection.ltr,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DoctorChatBubble(
              message: LanguageService.t('checkup_intro'),
              isRTL: LanguageService.isRTL,
            ),
            _buildQuestion(
              LanguageService.t('q_numbness'),
              const ['numb_none', 'numb_mild', 'numb_severe'],
              q1,
              (val) => setState(() => q1 = val),
            ),
            const SizedBox(height: 20),
            _buildQuestion(
              LanguageService.t('q_pain'),
              const ['pain_none', 'pain_mild', 'pain_severe'],
              q2,
              (val) => setState(() => q2 = val),
            ),
            const SizedBox(height: 20),
            _buildQuestion(
              LanguageService.t('q_wound'),
              const ['answer_no', 'answer_yes'],
              q3,
              (val) => setState(() => q3 = val),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _allAnswered() ? _showResult : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
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

  // optionKeys دلوقتي قايمة أكواد، بنترجمها وقت العرض بس بنخزّن الكود
  Widget _buildQuestion(String question, List<String> optionKeys,
      String? selected, Function(String) onSelect) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          question,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        ...optionKeys.map((key) {
          final bool isSelected = selected == key;
          return GestureDetector(
            onTap: () => onSelect(key),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? Colors.teal.shade50 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? Colors.teal : Colors.grey.shade300,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isSelected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: isSelected ? Colors.teal : Colors.grey,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      LanguageService.t(key),
                      style: const TextStyle(fontSize: 15),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}