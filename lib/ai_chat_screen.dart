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
        final bytes = await xFile.readAsBytes();
        if (bytes.lengthInBytes > 4000000) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(LanguageService.t('photo_size_error'))));
          return;
        }
        final base64Image = base64Encode(bytes);
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
    final groqKey = ApiConfig.groqApiKey;
    if (groqKey.isEmpty || groqKey == 'YOUR_GROQ_API_KEY') {
      if (!mounted) return;
      setState(() {
        _messages.add({'role': 'model', 'text': LanguageService.t('ai_key_error')});
        _loading = false;
      });
      return;
    }
    String? result;
    for (int attempt = 0; attempt < 2; attempt++) {
      if (attempt > 0) await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      try {
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
            'max_tokens': 1000,
          }),
        );
        if (!mounted) return;
        if (response.statusCode == 200) {
          final body = jsonDecode(response.body);
          result = body['choices']?[0]?['message']?['content'] as String?;
          break;
        }
      } catch (_) {}
    }
    if (!mounted) return;
    if (result != null) {
      setState(() => _messages.add({'role': 'model', 'text': result!.trim()}));
    } else {
      setState(() => _messages.add({'role': 'model', 'text': LanguageService.t('ai_no_response')}));
    }
    _loading = false;
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
      'Respond like ChatGPT: thorough, clear, and naturally structured. '
      'Always answer in the SAME LANGUAGE the user writes to you (Arabic, English, or French). '

      'For every response: '
      '1. Start by directly answering the question. '
      '2. Then explain in detail - give causes, symptoms, treatments, and prevention tips. '
      '3. Use paragraphs and bullet points for readability. '
      '4. Mention StepGuard app features when relevant (daily checkup, touch test, temperature, photo AI analysis, risk assessment, history, report, tips, AI chat). '
      '5. Be warm and compassionate. '
      '6. For emergencies (black tissue, spreading redness, fever with wound, sudden severe pain), advise seeking immediate medical attention first. '

      'Your medical knowledge includes: daily foot care, neuropathy (symptoms, 10g monofilament test, treatment), '
      'peripheral artery disease (symptoms, ABI, treatment), ulcer classification (Wagner 0-5), '
      'offloading (total contact cast), wound care (TIME principle, dressings), '
      'infections (antibiotics, osteomyelitis), Charcot foot, temperature monitoring (normal 28-33C, asymmetry >2.2C = inflammation), '
      'risk stratification, blood sugar control (HbA1c <7%), exercise, smoking cessation, '
      'foot surgery, skin conditions, IWGDF/ADA/NICE/IDSA guidelines. '
      'Always emphasize prevention and being evidence-based.';

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

      if (_messages.length > 10) {
        _messages.removeRange(0, _messages.length - 10);
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
          'temperature': 0.5,
          'max_tokens': 4096,
          'top_p': 0.9,
          'frequency_penalty': 0.3,
          'presence_penalty': 0.3,
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
                style: TextStyle(fontSize: 14, height: 1.5, color: Theme.of(context).colorScheme.onSurface),
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
