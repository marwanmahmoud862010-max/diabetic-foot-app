import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'api_config.dart';
import 'language_service.dart';
import 'doctor_avatar.dart';
import 'widgets/dark_mode_toggle.dart';
import 'connectivity_service.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, String>> _messages = [];
  bool _loading = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    LanguageService.currentLang.addListener(_onLangChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _addGreeting());
  }

  void _onLangChanged() {
    if (mounted) setState(() {});
  }

  void _addGreeting() {
    if (mounted && _messages.isEmpty) {
      setState(() {
        _messages.add({
          'role': 'model',
          'text': LanguageService.t('ai_chat_greeting'),
        });
      });
    }
  }

  @override
  void dispose() {
    LanguageService.currentLang.removeListener(_onLangChanged);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showAttachmentSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.attach_file, color: Colors.teal),
              title: Text(LanguageService.t('attach_file')),
              subtitle: Text(LanguageService.t('attach_file'), style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              onTap: () { Navigator.pop(ctx); _pickFile(); },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.teal),
              title: Text(LanguageService.t('attach_media')),
              subtitle: Text(LanguageService.t('attach_media'), style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              onTap: () { Navigator.pop(ctx); _pickMedia(); },
            ),
            ListTile(
              leading: const Icon(Icons.mic, color: Colors.teal),
              title: Text(LanguageService.t('attach_voice')),
              subtitle: Text(LanguageService.t('attach_voice'), style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              onTap: () { Navigator.pop(ctx); _startRecording(); },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFile() async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(LanguageService.t('attach_file')),
    ));
  }

  Future<void> _pickMedia() async {
    try {
      final xFile = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1024, maxHeight: 1024);
      if (xFile != null) {
        final base64Image = base64Encode(await xFile.readAsBytes());
        if (!mounted) return;
        setState(() => _messages.add({'role': 'user', 'text': LanguageService.t('attach_sent_media')}));
        _scrollToBottom();
        await _analyzeImage(base64Image);
      }
    } catch (_) {}
  }

  Future<void> _startRecording() async {
    setState(() => _messages.add({'role': 'user', 'text': LanguageService.t('attach_sent_voice')}));
    _scrollToBottom();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Voice recording feature coming soon')));
  }

  Future<void> _analyzeImage(String base64Image) async {
    setState(() => _loading = true);
    try {
      final groqKey = ApiConfig.groqApiKey;
      if (groqKey.isEmpty || groqKey == 'YOUR_GROQ_API_KEY') {
        setState(() {
          _messages.add({'role': 'model', 'text': LanguageService.t('ai_key_error')});
          _loading = false;
        });
        return;
      }
      final response = await http.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $groqKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'meta-llama/llama-4-scout-17b-16e-instruct',
          'messages': [
            {'role': 'user', 'content': [
              {'type': 'text', 'text': LanguageService.t('photo_ai_prompt')},
              {'type': 'image_url', 'image_url': {'url': 'data:image/jpeg;base64,$base64Image'}},
            ]},
          ],
          'max_tokens': 200,
        }),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final aiText = body['choices']?[0]?['message']?['content'] ?? LanguageService.t('ai_no_response');
        setState(() => _messages.add({'role': 'model', 'text': aiText.trim()}));
      } else {
        setState(() => _messages.add({'role': 'model', 'text': '${LanguageService.t('ai_error')}HTTP ${response.statusCode}'}));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _messages.add({'role': 'model', 'text': '${LanguageService.t('ai_connection_error')}${e.toString()}'}));
    }
    if (!mounted) return;
    setState(() => _loading = false);
    _scrollToBottom();
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _loading) return;
    if (!await ConnectivityService.check()) {
      setState(() => _messages.add({'role': 'model', 'text': LanguageService.t('offline_desc')}));
      return;
    }
    _controller.clear();

    setState(() {
      _messages.add({'role': 'user', 'text': text});
      _loading = true;
    });
    _scrollToBottom();

    await _getAIResponse(text);
  }

  static const String _systemPrompt = 'You are SoleMate, an AI assistant specialized in diabetic foot care. '
      'Answer in the SAME LANGUAGE the user writes to you (Arabic, English, or French). '
      'Answer comprehensively and in detail - full explanations, complete information, no shortcuts. '
      'No markdown, bold, asterisks, or bullet points. '
      'Mention StepGuard app features when relevant (daily checkup, touch test, temperature, photo AI analysis, risk assessment, history, report, tips, AI chat). '
      'Be compassionate and accurate. For emergencies (black tissue, spreading redness, fever with wound, sudden severe pain), advise seeking immediate medical attention. '
      'You have knowledge across these key areas: '

      'DAILY FOOT CARE: Inspect feet daily for cuts, blisters, redness, swelling, calluses. '
      'Wash in lukewarm water, dry gently especially between toes. '
      'Moisturize heels but NOT between toes. Trim nails straight across. '
      'Never treat corns/calluses yourself. Never walk barefoot. '
      'Wear clean socks, proper footwear (extra depth, wide toe box). '
      'Check inside shoes before wearing. '

      'NEUROPATHY: Loss of sensation from high blood sugar damaging nerves. '
      'Symptoms: tingling, burning, numbness, sharp pains. '
      'Diagnosis: 10g monofilament test, vibration testing. '
      'Treatment: pregabalin, duloxetine, gabapentin. Strict glucose control. '
      'Up to 50% of cases are asymptomatic - annual screening essential. '

      'PERIPHERAL ARTERY DISEASE (PAD): Reduced blood flow, present in up to 50% of DFU patients. '
      'Symptoms: cold feet, leg pain when walking (claudication), slow healing, weak pulses. '
      'Diagnosis: ankle-brachial index (ABI). '
      'Treatment: smoking cessation, antiplatelet therapy, statin, exercise, revascularization if needed. '

      'ULCER CLASSIFICATION: Wagner (0-5), University of Texas (grade x stage). '
      'IDSA infection severity: uninfected, mild, moderate, severe. '

      'OFFLOADING: Gold standard is total contact cast (TCC) for neuropathic plantar ulcers. '
      'Removable walker is second choice. Custom diabetic footwear after healing. '

      'WOUND CARE: Debridement (sharp, surgical, enzymatic, autolytic). '
      'TIME principle: Tissue, Infection, Moisture, Edge. '
      'Dressings: alginates (heavy exudate), foams (moderate), hydrocolloids (light), hydrogels (dry wounds), '
      'silver/honey for infection, NPWT for large deep wounds. '
      'Moist wound healing: wounds heal 40% faster in moist environment. '

      'INFECTIONS: Do NOT use antibiotics for uninfected ulcers. '
      'Mild: oral antibiotics targeting gram-positives. '
      'Moderate-severe: IV broad-spectrum, urgent surgical consultation. '
      'Osteomyelitis: probe-to-bone test, MRI, bone biopsy. Treatment: surgical resection + antibiotics. '

      'CHARCOT FOOT: Hot, red, swollen, painless foot. Midfoot collapse. '
      'Treatment: total contact cast, strict non-weight-bearing 8-12 weeks. '
      'Can be mistaken for infection or DVT. '

      'TEMPERATURE: Normal foot 28-33C. Asymmetry >2.2C between feet = inflammation. '
      'Daily monitoring reduces ulcer risk by 50-60%. '

      'RISK STRATIFICATION: Low (annual follow-up), Moderate (3-6 months), High (1-2 months specialist), Active (immediate referral). '

      'BLOOD SUGAR CONTROL: HbA1c target <7%. Pre-meal 80-130 mg/dL, post-meal <180 mg/dL. '
      'Medications: metformin, SGLT2 inhibitors, GLP-1 agonists, insulin. '

      'EXERCISE: Non-weight-bearing for active ulcers (swimming, cycling). '
      'Smoking cessation reduces amputation risk by 50%. '
      'Adequate protein (1-1.5 g/kg) for wound healing. '

      'FOOT SURGERY: Indicated for infection drainage, debridement, revascularization, amputation, Charcot reconstruction. '
      'Amputation levels: toe, ray, transmetatarsal, below-knee, above-knee. '
      'Preserve as much limb length as possible. BKA preserves knee function. '

      'SKIN CONDITIONS: Xerosis (dry skin), tinea pedis (athletes foot), onychomycosis (nail fungus), '
      'calluses, fissures, ingrown toenails. All need professional care in diabetic patients. '

      'GUIDELINES: IWGDF (international), ADA (US), NICE (UK), IDSA (infections). '
      'Follow IWGDF practical guidelines updated every 2 years. '

      'PREVENTION: After ulcer healing, lifetime protective footwear. '
      'Daily self-inspection, regular podiatry, glycemic control, smoking cessation. '
      '40% recurrence within 1 year without prevention. '

      'StepGuard app features: daily checkup, touch test, temperature, '
      'foot photo AI analysis, risk assessment, history with search, '
      'doctor report with PDF and WhatsApp, prevention tips, AI chat, '
      'profile, 3 daily reminders, dark mode, 3 languages. '
      'Be compassionate, evidence-based, and always emphasize prevention.';

  Future<void> _getAIResponse(String userMessage) async {
    try {
      final groqKey = ApiConfig.groqApiKey;
      if (groqKey.isEmpty || groqKey == 'YOUR_GROQ_API_KEY') {
        setState(() {
          _messages.add({'role': 'model', 'text': LanguageService.t('ai_key_error')});
          _loading = false;
        });
        _scrollToBottom();
        return;
      }

      final messages = <Map<String, String>>[
        {'role': 'system', 'content': _systemPrompt},
      ];
      for (final msg in _messages) {
        messages.add({'role': msg['role']! == 'user' ? 'user' : 'assistant', 'content': msg['text']!});
      }

      final response = await http.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $groqKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'llama-3.3-70b-versatile',
          'messages': messages,
          'temperature': 0.7,
          'max_tokens': 2048,
          'top_p': 0.9,
        }),
      );

      if (!mounted) return;
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final aiText = body['choices']?[0]?['message']?['content'] ?? LanguageService.t('ai_no_response');
        setState(() {
          _messages.add({'role': 'model', 'text': aiText.trim()});
          _loading = false;
        });
        _scrollToBottom();
        return;
      }

      final err = jsonDecode(response.body);
      final errMsg = err['error']?['message'] ?? 'HTTP ${response.statusCode}';
      setState(() {
        _messages.add({'role': 'model', 'text': '${LanguageService.t('ai_error')}$errMsg'});
        _loading = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add({'role': 'model', 'text': '${LanguageService.t('ai_connection_error')}${e.toString()}'});
        _loading = false;
      });
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRTL = LanguageService.isRTL;
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F3),
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_awesome, color: Colors.white, size: 22),
            const SizedBox(width: 8),
            Text(LanguageService.t('ai_chat_title')),
          ],
        ),
        centerTitle: true,
        elevation: 0,
        actions: [const DarkModeToggle()],
      ),
      body: Directionality(
        textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
        child: Column(
          children: [
            Expanded(
              child: _messages.isEmpty
                  ? const SizedBox.shrink()
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
                      itemCount: _messages.length + (_loading ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _messages.length) {
                          return _buildTypingIndicator(isRTL);
                        }
                        final msg = _messages[index];
                        if (msg['role'] == 'user') {
                          return _buildUserMessage(msg['text']!, isRTL);
                        }
                        return _buildAiMessage(msg['text']!, isRTL);
                      },
                    ),
            ),
            _buildInputBar(isRTL),
          ],
        ),
      ),
    );
  }

  Widget _buildUserMessage(String text, bool isRTL) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF004D40),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: isRTL ? const Radius.circular(16) : const Radius.circular(4),
                  bottomLeft: const Radius.circular(16),
                  bottomRight: const Radius.circular(16),
                ),
              ),
              child: Text(
                text,
                style: const TextStyle(fontSize: 14, color: Colors.white, height: 1.4),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outlineVariant,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person, color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildAiMessage(String text, bool isRTL) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DoctorAvatar(size: 38, label: 'SoleMate'),
          const SizedBox(width: 10),
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.only(
                  topLeft: isRTL ? const Radius.circular(16) : const Radius.circular(4),
                  topRight: isRTL ? const Radius.circular(4) : const Radius.circular(16),
                  bottomLeft: const Radius.circular(16),
                  bottomRight: const Radius.circular(16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: SelectableText(
                text,
                style: const TextStyle(fontSize: 14, height: 1.5, color: Color(0xFF333333)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator(bool isRTL) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DoctorAvatar(size: 38, label: 'SoleMate'),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.only(
                topLeft: isRTL ? const Radius.circular(16) : const Radius.circular(4),
                topRight: isRTL ? const Radius.circular(4) : const Radius.circular(16),
                bottomLeft: const Radius.circular(16),
                bottomRight: const Radius.circular(16),
              ),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.teal.shade400),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  LanguageService.t('ai_chat_think'),
                  style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(bool isRTL) {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 8, 12, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Colors.teal),
            onPressed: _loading ? null : _showAttachmentSheet,
          ),
          Expanded(
            child: TextField(
              controller: _controller,
              textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
              decoration: InputDecoration(
                hintText: LanguageService.t('ai_chat_hint'),
                hintTextDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFF00897B), Color(0xFF004D40)],
              ),
            ),
            child: IconButton(
              icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              onPressed: _loading ? null : _sendMessage,
            ),
          ),
        ],
      ),
    );
  }
}
