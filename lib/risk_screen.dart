import 'package:flutter/material.dart';
import 'language_service.dart';
import 'storage_service.dart';

class RiskScreen extends StatefulWidget {
  const RiskScreen({super.key});

  @override
  State<RiskScreen> createState() => _RiskScreenState();
}

class _RiskScreenState extends State<RiskScreen> {
  int riskScore = 0;

  @override
  void initState() {
    super.initState();
    _calculateRisk();
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

  Future<void> _calculateRisk() async {
    final checkup = await StorageService.getLastCheckup();
    final touch = await StorageService.getLastTouchTest();
    final temp = await StorageService.getLastTemperature();

    int score = 0;

    if (checkup['result'] == 'checkup_danger') score += 1;
    if (touch['result'] == 'touch_cat1') score += 1;
    if (touch['result'] == 'touch_cat2') score += 2;
    if (temp['result'] == 'temp_danger') score += 1;

    setState(() => riskScore = score);
  }

  String _getRiskCategoryKey() {
    if (riskScore == 0) return 'risk_cat_0';
    if (riskScore <= 1) return 'risk_cat_1';
    if (riskScore <= 2) return 'risk_cat_2';
    return 'risk_cat_3';
  }

  String _getRecommendationKey() {
    if (riskScore == 0) return 'risk_rec_0';
    if (riskScore <= 1) return 'risk_rec_1';
    if (riskScore <= 2) return 'risk_rec_2';
    return 'risk_rec_3';
  }

  Color _getRiskColor() {
    if (riskScore == 0) return Colors.green;
    if (riskScore <= 1) return Colors.orange;
    if (riskScore <= 2) return Colors.deepOrange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(LanguageService.t('risk_assessment')),
        centerTitle: true,
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Directionality(
        textDirection: LanguageService.isRTL ? TextDirection.rtl : TextDirection.ltr,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _getRiskColor().withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _getRiskColor()),
              ),
              child: Column(
                children: [
                  Text(
                    LanguageService.t(_getRiskCategoryKey()),
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _getRiskColor()),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${LanguageService.t('risk_score')}: $riskScore',
                    style: const TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(LanguageService.t('risk_recommendations'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                LanguageService.t(_getRecommendationKey()),
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
