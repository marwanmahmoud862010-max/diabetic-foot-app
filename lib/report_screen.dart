import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'storage_service.dart';
import 'language_service.dart';
import 'widgets/dark_mode_toggle.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  late Future<Map<String, dynamic>> reportFuture;
  Map<String, dynamic>? reportData;

  @override
  void initState() {
    super.initState();
    reportFuture = _generateReport();
    LanguageService.currentLang.addListener(_onLangChanged);
  }

  void _onLangChanged() {
    if (mounted) {
      setState(() {});
      reportFuture = _generateReport();
    }
  }

  @override
  void dispose() {
    LanguageService.currentLang.removeListener(_onLangChanged);
    super.dispose();
  }

  Future<Map<String, dynamic>> _generateReport() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('name') ?? LanguageService.t('report_no_name');
    final age = prefs.getString('age') ?? LanguageService.t('report_no_age');
    final diabetesYears = prefs.getString('diabetes_years') ?? LanguageService.t('report_no_age');
    final diabetesType = prefs.getString('diabetes_type') ?? LanguageService.t('report_no_age');
    final phone = prefs.getString('phone') ?? '';
    final doctorPhone = prefs.getString('doctor_phone') ?? '';

    final history = await StorageService.getFullHistory();
    final lastCheckup = await StorageService.getLastCheckup();
    final lastTouch = await StorageService.getLastTouchTest();
    final lastTemp = await StorageService.getLastTemperature();
    final risk = await StorageService.getLastRiskAssessment();

    final data = {
      'name': name,
      'age': age,
      'diabetesYears': diabetesYears,
      'diabetesType': diabetesType,
      'phone': phone,
      'doctorPhone': doctorPhone,
      'history': history,
      'lastCheckup': lastCheckup,
      'lastTouch': lastTouch,
      'lastTemp': lastTemp,
      'riskLevel': risk['level'],
      'riskTitle': risk['title'],
    };
    reportData = data;
    return data;
  }

  String _riskEmoji(int level) {
    switch (level) {
      case 0: return '\u{1F7E2}';
      case 1: return '\u{1F7E1}';
      case 2: return '\u{1F534}';
      case 3: return '\u{26A0}\u{FE0F}';
      default: return '\u{26AA}';
    }
  }

  String _formatHistoryDate(String date) {
    if (date.length >= 10) return date.substring(0, 10);
    return date;
  }

  String _resultIcon(String? result) {
    if (result == null || result.isEmpty) return '';
    if (result.contains('ok') || result.contains('normal') || result.contains('cat0')) return '\u2705';
    if (result.contains('danger') || result.contains('cat2')) return '\u{1F6A8}';
    return '\u26A0\u{FE0F}';
  }

  Future<void> _generatePdf() async {
    if (reportData == null) return;
    final d = reportData!;
    final prefs = await SharedPreferences.getInstance();
    final doctorPhone = prefs.getString('doctor_phone') ?? '';

    final riskLevel = (d['riskLevel'] as int?) ?? 0;
    final riskTitle = d['riskTitle'] as String? ?? '';
    final riskRecKey = 'risk_rec_${riskLevel.toString()}';
    final riskAdviceKey = 'risk_advice_${riskLevel.toString()}';

    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (ctx) => [
          pw.Center(
            child: pw.Column(
              children: [
                pw.Text('StepGuard', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.teal)),
                pw.SizedBox(height: 4),
                pw.Text(LanguageService.t('report_title'), style: pw.TextStyle(fontSize: 16, color: PdfColors.grey)),
                pw.SizedBox(height: 4),
                pw.Text('${LanguageService.t('report_date')}: ${DateTime.now().toString().substring(0, 10)}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Divider(thickness: 1.5),
          pw.SizedBox(height: 16),

          _pdfSectionTitle(LanguageService.t('report_patient_data')),
          pw.SizedBox(height: 8),
          _pdfInfoRow(LanguageService.t('report_name'), d['name']),
          _pdfInfoRow(LanguageService.t('report_age'), d['age']),
          _pdfInfoRow(LanguageService.t('report_diabetes_type'), d['diabetesType']),
          _pdfInfoRow(LanguageService.t('report_duration'), '${d['diabetesYears']} ${LanguageService.t('report_years')}'),
          if ((d['phone'] as String).isNotEmpty)
            _pdfInfoRow(LanguageService.t('phone_label'), d['phone']),
          pw.SizedBox(height: 16),

          pw.Divider(thickness: 1),
          pw.SizedBox(height: 12),

          _pdfSectionTitle(LanguageService.t('report_last_results')),
          pw.SizedBox(height: 8),
          _pdfResultRow(LanguageService.t('report_checkup'), LanguageService.t(d['lastCheckup']['result'] ?? 'report_no_data'), _resultIcon(d['lastCheckup']['result'])),
          _pdfResultRow(LanguageService.t('report_touch'), LanguageService.t(d['lastTouch']['result'] ?? 'report_no_data'), _resultIcon(d['lastTouch']['result'])),
          _pdfResultRow(LanguageService.t('report_temp'), d['lastTemp']['result'] ?? LanguageService.t('report_no_data'), ''),
          if (riskTitle.isNotEmpty)
            _pdfResultRow(LanguageService.t('report_risk'), '${_riskEmoji(riskLevel)} ${LanguageService.t(riskTitle)} (${LanguageService.t('risk_score')}: $riskLevel)', ''),
          pw.SizedBox(height: 16),

          pw.Divider(thickness: 1),
          pw.SizedBox(height: 12),

          _pdfSectionTitle(LanguageService.t('report_recommendations')),
          pw.SizedBox(height: 8),
          pw.Bullet(text: LanguageService.t(riskRecKey), style: pw.TextStyle(fontSize: 11)),
          pw.SizedBox(height: 4),
          pw.Bullet(text: LanguageService.t(riskAdviceKey), style: pw.TextStyle(fontSize: 11)),
          pw.SizedBox(height: 12),

          pw.Divider(thickness: 1),
          pw.SizedBox(height: 12),

          _pdfSectionTitle('${LanguageService.t('report_history')} (${d['history'].length} ${LanguageService.t('report_exams')})'),
          pw.SizedBox(height: 8),
          if ((d['history'] as List).isEmpty)
            pw.Text(LanguageService.t('no_history'), style: const pw.TextStyle(color: PdfColors.grey))
          else
            ...(d['history'] as List).reversed.take(7).map((item) {
              final date = _formatHistoryDate(item['date']);
              final type = item['type'] == 'daily_checkup'
                  ? LanguageService.t('daily_checkup')
                  : item['type'] == 'touch_test'
                      ? LanguageService.t('touch_test')
                      : item['type'] == 'temperature'
                          ? LanguageService.t('temperature')
                          : item['type'];
              final resultText = (item['result'] as String? ?? '').startsWith('risk_')
                  ? LanguageService.t(item['result'])
                  : (item['result'] as String? ?? '').startsWith('checkup_') || (item['result'] as String? ?? '').startsWith('touch_') || (item['result'] as String? ?? '').startsWith('temp_')
                      ? LanguageService.t(item['result'])
                      : item['result'];
              return pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 2),
                child: pw.Text('\u2022 $date - $type: $resultText', style: const pw.TextStyle(fontSize: 10)),
              );
            }),
          pw.SizedBox(height: 16),

          pw.Divider(thickness: 1),
          pw.SizedBox(height: 12),

          _pdfSectionTitle(LanguageService.t('doctor_contact')),
          pw.SizedBox(height: 6),
          if (doctorPhone.isNotEmpty)
            pw.Text('${LanguageService.t('doctor_phone')}: $doctorPhone', style: const pw.TextStyle(fontSize: 11))
          else
            pw.Text(LanguageService.t('no_doctor_number'), style: pw.TextStyle(fontSize: 11, color: PdfColors.orange)),
          pw.SizedBox(height: 20),

          pw.Divider(thickness: 0.5),
          pw.SizedBox(height: 8),
          pw.Text(
            LanguageService.t('report_note'),
            style: pw.TextStyle(fontSize: 9, color: PdfColors.grey),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            '${LanguageService.t('report_copyright')} StepGuard',
            style: pw.TextStyle(fontSize: 9, color: PdfColors.grey),
          ),
        ],
      ),
    );

    final bytes = await pdf.save();
    if (!mounted) return;
    await Printing.sharePdf(bytes: Uint8List.fromList(bytes), filename: '${LanguageService.t('pdf_filename')}.pdf');
  }

  pw.Widget _pdfSectionTitle(String title) {
    return pw.Text(title, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.teal));
  }

  pw.Widget _pdfInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('$label:', style: const pw.TextStyle(fontSize: 11)),
          pw.Text(value, style: const pw.TextStyle(fontSize: 11)),
        ],
      ),
    );
  }

  pw.Widget _pdfResultRow(String label, String value, String icon) {
    return pw.Container(
      margin: const pw.EdgeInsets.symmetric(vertical: 3),
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey50,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('$icon $label', style: const pw.TextStyle(fontSize: 11)),
          pw.Text(value, style: const pw.TextStyle(fontSize: 11)),
        ],
      ),
    );
  }

  Future<void> _sendToWhatsApp() async {
    if (reportData == null) return;
    final d = reportData!;
    final prefs = await SharedPreferences.getInstance();
    final doctorPhone = prefs.getString('doctor_phone') ?? '';

    if (doctorPhone.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LanguageService.t('no_doctor_number'))),
      );
      return;
    }

    final riskLevel = (d['riskLevel'] as int?) ?? 0;
    final riskTitle = d['riskTitle'] as String? ?? '';
    final riskRecKey = 'risk_rec_${riskLevel.toString()}';
    final riskAdviceKey = 'risk_advice_${riskLevel.toString()}';

    final historyEntries = (d['history'] as List).reversed.take(7).map((item) {
      final date = _formatHistoryDate(item['date']);
      final type = item['type'] == 'daily_checkup'
          ? LanguageService.t('daily_checkup')
          : item['type'] == 'touch_test'
              ? LanguageService.t('touch_test')
              : item['type'] == 'temperature'
                  ? LanguageService.t('temperature')
                  : item['type'];
      final resultText = (item['result'] as String? ?? '').startsWith('risk_')
          ? LanguageService.t(item['result'])
          : (item['result'] as String? ?? '').startsWith('checkup_') || (item['result'] as String? ?? '').startsWith('touch_') || (item['result'] as String? ?? '').startsWith('temp_')
              ? LanguageService.t(item['result'])
              : item['result'];
      return '$date | $type | $resultText';
    }).join('\n');

    final message = [
      'StepGuard - ${LanguageService.t('report_title')}',
      '━━━━━━━━━━━━━━━━━━━━━━━',
      '',
      '👤 ${LanguageService.t('report_patient_data')}',
      '${LanguageService.t('report_name')}: ${d['name']}',
      '${LanguageService.t('report_age')}: ${d['age']}',
      '${LanguageService.t('report_diabetes_type')}: ${d['diabetesType']}',
      '${LanguageService.t('report_duration')}: ${d['diabetesYears']} ${LanguageService.t('report_years')}',
      if ((d['phone'] as String).isNotEmpty)
        '${LanguageService.t('phone_label')}: ${d['phone']}',
      '${LanguageService.t('report_date')}: ${DateTime.now().toString().substring(0, 10)}',
      '',
      '━━━━━━━━━━━━━━━━━━━━━━━',
      '',
      '🩺 ${LanguageService.t('report_last_results')}',
      '${_resultIcon(d['lastCheckup']['result'])} ${LanguageService.t('report_checkup')}: ${LanguageService.t(d['lastCheckup']['result'] ?? 'report_no_data')}',
      '${_resultIcon(d['lastTouch']['result'])} ${LanguageService.t('report_touch')}: ${LanguageService.t(d['lastTouch']['result'] ?? 'report_no_data')}',
      '${LanguageService.t('report_temp')}: ${d['lastTemp']['result'] ?? LanguageService.t('report_no_data')}',
      if (riskTitle.isNotEmpty)
        '${_riskEmoji(riskLevel)} ${LanguageService.t('report_risk')}: ${LanguageService.t(riskTitle)} (${LanguageService.t('risk_score')}: $riskLevel)',
      '',
      '━━━━━━━━━━━━━━━━━━━━━━━',
      '',
      '💡 ${LanguageService.t('report_recommendations')}',
      '• ${LanguageService.t(riskRecKey)}',
      '• ${LanguageService.t(riskAdviceKey)}',
      '',
      '━━━━━━━━━━━━━━━━━━━━━━━',
      '',
      '📆 ${LanguageService.t('report_history')} (${d['history'].length} ${LanguageService.t('report_exams')})',
      historyEntries.isNotEmpty ? historyEntries : LanguageService.t('no_history'),
      '',
      '━━━━━━━━━━━━━━━━━━━━━━━',
      '',
      '📞 ${LanguageService.t('doctor_phone')}: $doctorPhone',
      '',
      LanguageService.t('report_note'),
      '---',
      'StepGuard',
    ].join('\n');

    final phone = doctorPhone.replaceAll(RegExp(r'[^0-9]'), '');
    final encoded = Uri.encodeComponent(message);
    final uris = [
      Uri.parse('whatsapp://send?phone=$phone&text=$encoded'),
      Uri.parse('https://api.whatsapp.com/send?phone=$phone&text=$encoded'),
    ];

    bool opened = false;
    for (final uri in uris) {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        opened = true;
        break;
      } catch (_) {
        continue;
      }
    }

    if (!mounted) return;
    if (opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LanguageService.t('whatsapp_sent'))),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LanguageService.t('whatsapp_not_found'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(LanguageService.t('doctor_report')),
        centerTitle: true,
        actions: [const DarkModeToggle()],
      ),
      body: Directionality(
        textDirection: LanguageService.isRTL ? TextDirection.rtl : TextDirection.ltr,
        child: FutureBuilder<Map<String, dynamic>>(
          future: reportFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData) {
              return Center(child: Text(LanguageService.t('report_loading')));
            }

            final data = snapshot.data!;
            final riskLevel = (data['riskLevel'] as int?) ?? 0;
            final riskTitle = data['riskTitle'] as String? ?? '';
            final riskRecKey = 'risk_rec_$riskLevel';
            final riskAdviceKey = 'risk_advice_$riskLevel';

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.teal.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.person, color: Colors.teal),
                          const SizedBox(width: 8),
                          Text(LanguageService.t('report_patient_data'),
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildInfoRow(LanguageService.t('report_name'), data['name']),
                      _buildInfoRow(LanguageService.t('report_age'), data['age']),
                      _buildInfoRow(LanguageService.t('report_diabetes_type'), data['diabetesType']),
                      _buildInfoRow(LanguageService.t('report_duration'), '${data['diabetesYears']} ${LanguageService.t('report_years')}'),
                      if ((data['phone'] as String).isNotEmpty)
                        _buildInfoRow(LanguageService.t('phone_label'), data['phone']),
                      _buildInfoRow(LanguageService.t('report_date'), DateTime.now().toString().substring(0, 10)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.monitor_heart, color: Colors.blue),
                          const SizedBox(width: 8),
                          Text(LanguageService.t('report_last_results'),
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildResult(LanguageService.t('report_checkup'), LanguageService.t(data['lastCheckup']['result'] ?? 'report_no_data'), data['lastCheckup']['result']),
                      _buildResult(LanguageService.t('report_touch'), LanguageService.t(data['lastTouch']['result'] ?? 'report_no_data'), data['lastTouch']['result']),
                      _buildResult(LanguageService.t('report_temp'), data['lastTemp']['result'] ?? LanguageService.t('report_no_data'), ''),
                      if (riskTitle.isNotEmpty)
                        _buildResult(LanguageService.t('report_risk'),
                            '${_riskEmoji(riskLevel)} ${LanguageService.t(riskTitle)} (${LanguageService.t('risk_score')}: $riskLevel)', ''),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
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
                          const Icon(Icons.lightbulb, color: Colors.green),
                          const SizedBox(width: 8),
                          Text(LanguageService.t('report_recommendations'),
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text('• ${LanguageService.t(riskRecKey)}',
                          style: const TextStyle(fontSize: 13)),
                      const SizedBox(height: 6),
                      Text('• ${LanguageService.t(riskAdviceKey)}',
                          style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.purple.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.history, color: Colors.purple),
                          const SizedBox(width: 8),
                          Text('${LanguageService.t('report_history')} (${data['history'].length} ${LanguageService.t('report_exams')})',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if ((data['history'] as List).isEmpty)
                        Text(LanguageService.t('no_history'), style: const TextStyle(color: Colors.grey))
                      else
                        ...(data['history'] as List).reversed.take(7).map((item) {
                          final date = _formatHistoryDate(item['date']);
                          final type = item['type'] == 'daily_checkup'
                              ? LanguageService.t('daily_checkup')
                              : item['type'] == 'touch_test'
                                  ? LanguageService.t('touch_test')
                                  : item['type'] == 'temperature'
                                      ? LanguageService.t('temperature')
                                      : item['type'];
                          final resultText = (item['result'] as String? ?? '').startsWith('risk_')
                              ? LanguageService.t(item['result'])
                              : (item['result'] as String? ?? '').startsWith('checkup_') || (item['result'] as String? ?? '').startsWith('touch_') || (item['result'] as String? ?? '').startsWith('temp_')
                                  ? LanguageService.t(item['result'])
                                  : item['result'];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                const Text('• ', style: TextStyle(fontSize: 12)),
                                Expanded(child: Text('$date - $type', style: const TextStyle(fontSize: 12))),
                                Text(resultText, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    LanguageService.t('report_note'),
                    style: const TextStyle(fontSize: 12, color: Colors.orange),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _generatePdf,
                  icon: const Icon(Icons.picture_as_pdf),
                  label: Text(LanguageService.t('report_save_pdf')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _sendToWhatsApp,
                  icon: const Icon(Icons.chat),
                  label: Text(LanguageService.t('send_whatsapp')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          Expanded(child: Text(value, textAlign: TextAlign.end, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildResult(String label, String value, String? resultCode) {
    final icon = _resultIcon(resultCode);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Text('$icon ', style: const TextStyle(fontSize: 16)),
          Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
          Text(value, style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
        ],
      ),
    );
  }
}
