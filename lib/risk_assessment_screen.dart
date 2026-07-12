import 'package:flutter/material.dart';
import 'storage_service.dart';
import 'language_service.dart';
import 'doctor_avatar.dart';

class RiskAssessmentScreen extends StatefulWidget {
  const RiskAssessmentScreen({super.key});

  @override
  State<RiskAssessmentScreen> createState() => _RiskAssessmentScreenState();
}

class _RiskAssessmentScreenState extends State<RiskAssessmentScreen> {
  bool? lostSensation;
  bool? poorCirculation;
  bool? deformity;
  bool? pastUlcer;

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

  bool get _allAnswered =>
      lostSensation != null &&
      poorCirculation != null &&
      deformity != null &&
      pastUlcer != null;

  Map<String, dynamic> _calculateRisk() {
    final neuro = lostSensation == true;
    final pad = poorCirculation == true;
    final def = deformity == true;
    final ulcer = pastUlcer == true;

    if (ulcer) {
      return {'level': 3, 'titleKey': 'risk_level_3', 'adviceKey': 'risk_advice_3', 'color': Colors.red};
    }
    if (neuro && (pad || def)) {
      return {'level': 2, 'titleKey': 'risk_level_2', 'adviceKey': 'risk_advice_2', 'color': Colors.deepOrange};
    }
    if (neuro || pad) {
      return {'level': 1, 'titleKey': 'risk_level_1', 'adviceKey': 'risk_advice_1', 'color': Colors.orange};
    }
    return {'level': 0, 'titleKey': 'risk_level_0', 'adviceKey': 'risk_advice_0', 'color': Colors.green};
  }

  void _showResult() {
    final risk = _calculateRisk();
    StorageService.saveRiskAssessment(risk['level'], risk['titleKey']);

    showDialog(
      context: context,
      builder: (_) => Directionality(
        textDirection: LanguageService.isRTL ? TextDirection.rtl : TextDirection.ltr,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Column(
            children: [
              Icon(Icons.shield, color: risk['color'], size: 48),
              const SizedBox(height: 8),
              Text(
                '${LanguageService.t(risk['titleKey'])} (${LanguageService.t('risk_result')} ${risk['level']})',
                style: TextStyle(color: risk['color'], fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          content: Text(
            LanguageService.t(risk['adviceKey']),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, height: 1.5),
          ),
          actions: [
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(LanguageService.t('risk_ok')),
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
        title: Text(LanguageService.t('risk_assessment_full')),
        centerTitle: true,
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      backgroundColor: const Color(0xFFF0F4F3),
      body: Directionality(
        textDirection: LanguageService.isRTL ? TextDirection.rtl : TextDirection.ltr,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DoctorChatBubble(
              message: LanguageService.t('risk_assessment_intro'),
              isRTL: LanguageService.isRTL,
            ),
            const SizedBox(height: 20),
            _buildYesNo(LanguageService.t('risk_assessment_q1'), lostSensation, (v) => setState(() => lostSensation = v)),
            _buildYesNo(LanguageService.t('risk_assessment_q2'), poorCirculation, (v) => setState(() => poorCirculation = v)),
            _buildYesNo(LanguageService.t('risk_assessment_q3'), deformity, (v) => setState(() => deformity = v)),
            _buildYesNo(LanguageService.t('risk_assessment_q4'), pastUlcer, (v) => setState(() => pastUlcer = v)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _allAnswered ? _showResult : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(LanguageService.t('risk_assessment_calc'), style: const TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildYesNo(String question, bool? value, Function(bool) onSelect) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(question, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => onSelect(true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: value == true ? Colors.red.shade100 : Colors.white,
                      border: Border.all(
                        color: value == true ? Colors.red : Colors.grey.shade300,
                        width: value == true ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(LanguageService.t('risk_assessment_yes'), textAlign: TextAlign.center),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () => onSelect(false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: value == false ? Colors.green.shade100 : Colors.white,
                      border: Border.all(
                        color: value == false ? Colors.green : Colors.grey.shade300,
                        width: value == false ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(LanguageService.t('risk_assessment_no'), textAlign: TextAlign.center),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
