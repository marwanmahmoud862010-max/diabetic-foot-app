import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
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
    final diabetesYears = prefs.getString('diabetes_years') ?? LanguageService.t('report_no_data');
    final diabetesType = prefs.getString('diabetes_type') ?? LanguageService.t('report_no_data');
    final phone = prefs.getString('phone') ?? '';
    final doctorPhone = prefs.getString('doctor_phone') ?? '';

    final history = await StorageService.getFullHistory();
    final lastCheckup = await StorageService.getLastCheckup();
    final lastTouch = await StorageService.getLastTouchTest();
    final lastTemp = await StorageService.getLastTemperature();
    final risk = await StorageService.getLastRiskAssessment();
    final rightPhotos = await _withImageData(await StorageService.getPhotos('right'));
    final leftPhotos = await _withImageData(await StorageService.getPhotos('left'));

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
      'rightPhotos': rightPhotos,
      'leftPhotos': leftPhotos,
    };
    reportData = data;
    return data;
  }

  Future<List<Map<String, String>>> _withImageData(List<Map<String, String>> photos) async {
    final out = <Map<String, String>>[];
    for (final p in photos) {
      final data = p['data'] ?? '';
      final url = p['url'] ?? '';
      if (data.isEmpty && url.isNotEmpty) {
        try {
          final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
          if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
            out.add({...p, 'data': base64Encode(res.bodyBytes)});
            continue;
          }
        } catch (_) {}
      }
      out.add(p);
    }
    return out;
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

  Future<pw.ThemeData?> _pdfArabicTheme() async {
    if (!LanguageService.isRTL) return null;
    try {
      final base = await PdfGoogleFonts.cairoRegular();
      final bold = await PdfGoogleFonts.cairoBold();
      return pw.ThemeData.withFont(base: base, bold: bold);
    } catch (_) {
      return null;
    }
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

    final theme = await _pdfArabicTheme();
    final pdf = theme == null ? pw.Document() : pw.Document(theme: theme);
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
          _pdfInfoRow(LanguageService.t('report_diabetes_type'), LanguageService.t(d['diabetesType'])),
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
          _pdfResultRow(LanguageService.t('report_temp'), LanguageService.t(d['lastTemp']['result'] ?? 'report_no_data'), ''),
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

          _pdfSectionTitle(LanguageService.t('foot_photo')),
          pw.SizedBox(height: 8),
          ..._buildPdfPhotos(d),
          pw.SizedBox(height: 16),

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
          pw.Flexible(
            child: pw.Text(value,
                style: const pw.TextStyle(fontSize: 11),
                textAlign: pw.TextAlign.right),
          ),
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
          pw.Flexible(
            child: pw.Text(value,
                style: const pw.TextStyle(fontSize: 11),
                textAlign: pw.TextAlign.right),
          ),
        ],
      ),
    );
  }

  List<pw.Widget> _buildPdfPhotos(Map<String, dynamic> d) {
    final rightPhotos = d['rightPhotos'] as List? ?? [];
    final leftPhotos = d['leftPhotos'] as List? ?? [];
    final widgets = <pw.Widget>[];

    void addFootPhotos(String label, List<dynamic> photos) {
      if (photos.isEmpty) return;
      widgets.add(pw.Text(label, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)));
      widgets.add(pw.SizedBox(height: 4));
      for (int i = 0; i < photos.length; i++) {
        final p = photos[i];
        if (p is! Map<String, dynamic>) continue;
        final data = (p['data'] as String? ?? '');
        if (data.isEmpty) continue;
        try {
          if (i > 0) widgets.add(pw.SizedBox(height: 6));
          widgets.add(pw.Container(
            padding: const pw.EdgeInsets.all(4),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Image(pw.MemoryImage(base64Decode(data)), width: 200),
          ));
          widgets.add(pw.SizedBox(height: 2));
          widgets.add(pw.Text('${LanguageService.t('photo_image')} ${i + 1}', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey)));
        } catch (_) {}
      }
      widgets.add(pw.SizedBox(height: 8));
    }

    addFootPhotos(LanguageService.t('photo_right'), rightPhotos);
    addFootPhotos(LanguageService.t('photo_left'), leftPhotos);

    if (widgets.isEmpty) {
      widgets.add(pw.Text(LanguageService.t('no_photos'), style: pw.TextStyle(fontSize: 10, color: PdfColors.grey)));
    }
    return widgets;
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
      '${LanguageService.t('report_diabetes_type')}: ${LanguageService.t(d['diabetesType'])}',
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
      '${LanguageService.t('report_temp')}: ${LanguageService.t(d['lastTemp']['result'] ?? 'report_no_data')}',
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
      '━━━━━━━━━━━━━━━━━━━━━━━',
      '',
      '📷 ${LanguageService.t('foot_photo')}',
      ...() {
        final rightPhotos = d['rightPhotos'] as List? ?? [];
        final leftPhotos = d['leftPhotos'] as List? ?? [];
        final lines = <String>[];
        if (rightPhotos.isNotEmpty) lines.add('${LanguageService.t('photo_right')}: ✅ ${LanguageService.t('photos_available')}');
        if (leftPhotos.isNotEmpty) lines.add('${LanguageService.t('photo_left')}: ✅ ${LanguageService.t('photos_available')}');
        if (lines.isEmpty) lines.add(LanguageService.t('no_photos'));
        return lines;
      }(),
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
            if (snapshot.hasError) {
              return Center(child: Text('${LanguageService.t('report_loading')}: ${snapshot.error}'));
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
                    border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.person, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(LanguageService.t('report_patient_data'),
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildInfoRow(LanguageService.t('report_name'), data['name']),
                      _buildInfoRow(LanguageService.t('report_age'), data['age']),
                      _buildInfoRow(LanguageService.t('report_diabetes_type'), LanguageService.t(data['diabetesType'])),
                      _buildInfoRow(LanguageService.t('report_duration'), '${data['diabetesYears']} ${LanguageService.t('report_years')}'),
                      if ((data['phone'] as String).isNotEmpty)
                        _buildInfoRow(LanguageService.t('phone_label'), data['phone']),
                      _buildInfoRow(LanguageService.t('report_date'), DateTime.now().toString().substring(0, 10)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildThemeContainer(
                  color: Colors.blue,
                  icon: Icons.monitor_heart,
                  title: LanguageService.t('report_last_results'),
                  children: [
                    _buildResult(LanguageService.t('report_checkup'), LanguageService.t(data['lastCheckup']['result'] ?? 'report_no_data'), data['lastCheckup']['result']),
                    _buildResult(LanguageService.t('report_touch'), LanguageService.t(data['lastTouch']['result'] ?? 'report_no_data'), data['lastTouch']['result']),
                    _buildResult(LanguageService.t('report_temp'), LanguageService.t(data['lastTemp']['result'] ?? 'report_no_data'), ''),
                    if (riskTitle.isNotEmpty)
                      _buildResult(LanguageService.t('report_risk'),
                          '${_riskEmoji(riskLevel)} ${LanguageService.t(riskTitle)} (${LanguageService.t('risk_score')}: $riskLevel)', ''),
                  ],
                ),
                const SizedBox(height: 16),
                _buildThemeContainer(
                  color: Colors.green,
                  icon: Icons.lightbulb,
                  title: LanguageService.t('report_recommendations'),
                  children: [
                    Text('• ${LanguageService.t(riskRecKey)}',
                        style: const TextStyle(fontSize: 13)),
                    const SizedBox(height: 6),
                    Text('• ${LanguageService.t(riskAdviceKey)}',
                        style: const TextStyle(fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 16),
                _buildThemeContainer(
                  color: Colors.purple,
                  icon: Icons.history,
                  title: '${LanguageService.t('report_history')} (${data['history'].length} ${LanguageService.t('report_exams')})',
                  children: [
                    if ((data['history'] as List).isEmpty)
                      Text(LanguageService.t('no_history'), style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))
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
                              Flexible(child: Text(resultText, textAlign: TextAlign.end, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface))),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    LanguageService.t('report_note'),
                    style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _generatePdf,
                  icon: const Icon(Icons.picture_as_pdf),
                  label: Text(LanguageService.t('report_save_pdf')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
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

  Widget _buildThemeContainer({required Color color, required IconData icon, required String title, required List<Widget> children}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? color.withValues(alpha: 0.15) : color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: isDark ? 0.3 : 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
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
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Row(
        children: [
          Text('$icon ', style: const TextStyle(fontSize: 16)),
          Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
          Flexible(child: Text(value, textAlign: TextAlign.end, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13))),
        ],
      ),
    );
  }
}
