import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'language_service.dart';
import 'widgets/dark_mode_toggle.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key, this.sourceScreen});

  final String? sourceScreen;

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  static const String _whatsappNumber = '201028296544';

  String? _type;
  final TextEditingController _messageController = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _type = 'suggestion';
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  String _formatDateTime(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }

  Future<Map<String, String>> _collectDetails() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('name')?.trim() ?? '';
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email?.trim() ?? '';
    String version = '1.0.0';
    try {
      final info = await PackageInfo.fromPlatform();
      version = info.version;
    } catch (_) {}
    final now = _formatDateTime(DateTime.now());

    return {
      'name': name.isEmpty ? LanguageService.t('feedback_na') : name,
      'email': email.isEmpty ? LanguageService.t('feedback_na') : email,
      'version': version,
      'time': now,
      'screen': widget.sourceScreen?.isNotEmpty == true
          ? widget.sourceScreen!
          : LanguageService.t('feedback_screen_default'),
    };
  }

  Future<void> _send() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LanguageService.t('feedback_empty'))),
      );
      return;
    }
    if (_sending) return;

    final typeLabel = _type == 'report'
        ? LanguageService.t('feedback_type_report')
        : LanguageService.t('feedback_type_suggestion');
    final details = await _collectDetails();
    if (!mounted) return;

    setState(() => _sending = true);

    final text = [
      '📱 ${LanguageService.t('app_name')} - SoleMate',
      '',
      '📌 ${LanguageService.t('feedback_msg_type')}:',
      typeLabel,
      '',
      '📍 ${LanguageService.t('feedback_msg_screen')}:',
      details['screen']!,
      '',
      '👤 ${LanguageService.t('feedback_msg_user')}:',
      details['name']!,
      '',
      '📧 ${LanguageService.t('feedback_msg_email')}:',
      details['email']!,
      '',
      '📱 ${LanguageService.t('feedback_msg_version')}:',
      details['version']!,
      '',
      '🕒 ${LanguageService.t('feedback_msg_time')}:',
      details['time']!,
      '',
      '💬 ${LanguageService.t('feedback_msg_message')}:',
      message,
    ].join('\n');

    final encoded = Uri.encodeComponent(text);
    final phone = _whatsappNumber.replaceAll(RegExp(r'[^0-9]'), '');
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
    setState(() => _sending = false);
    if (opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LanguageService.t('feedback_sent'))),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LanguageService.t('whatsapp_not_found'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: Text(LanguageService.t('feedback_title')),
        centerTitle: true,
        actions: [const DarkModeToggle()],
      ),
      body: Directionality(
        textDirection: LanguageService.isRTL ? TextDirection.rtl : TextDirection.ltr,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [Colors.blue.shade800, Colors.blue.shade900]
                      : [const Color(0xFF00897B), const Color(0xFF004D40)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.campaign, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          LanguageService.t('feedback_title'),
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          LanguageService.t('feedback_intro'),
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _sectionLabel(cs, LanguageService.t('feedback_type')),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: InputDecoration(
                filled: true,
                fillColor: cs.surfaceContainerHighest,
                prefixIcon: Icon(Icons.category_outlined, color: cs.primary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: cs.outline),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: cs.outline),
                ),
              ),
              dropdownColor: cs.surfaceContainerHighest,
              items: [
                DropdownMenuItem(
                  value: 'suggestion',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lightbulb_outline, color: Colors.amber, size: 18),
                      const SizedBox(width: 8),
                      Text(LanguageService.t('feedback_type_suggestion'), style: TextStyle(color: cs.onSurface)),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: 'report',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.report_problem_outlined, color: Colors.redAccent, size: 18),
                      const SizedBox(width: 8),
                      Text(LanguageService.t('feedback_type_report'), style: TextStyle(color: cs.onSurface)),
                    ],
                  ),
                ),
              ],
              onChanged: (v) => setState(() => _type = v),
            ),
            const SizedBox(height: 20),
            _sectionLabel(cs, LanguageService.t('feedback_message_label')),
            const SizedBox(height: 8),
            TextField(
              controller: _messageController,
              maxLines: 6,
              minLines: 4,
              enabled: !_sending,
              textAlignVertical: TextAlignVertical.top,
              decoration: InputDecoration(
                hintText: LanguageService.t('feedback_message_hint'),
                filled: true,
                fillColor: cs.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: cs.outline),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: cs.outline),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: cs.primary, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _sending ? null : _send,
              icon: _sending
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send),
              label: Text(LanguageService.t('feedback_send')),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? Colors.blue.shade700 : const Color(0xFF25D366),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: cs.onSurfaceVariant, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${LanguageService.t('feedback_wa_note')}\n${LanguageService.t('feedback_wa_info')}',
                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(ColorScheme cs, String text) {
    return Text(
      text,
      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: cs.onSurface),
    );
  }
}
