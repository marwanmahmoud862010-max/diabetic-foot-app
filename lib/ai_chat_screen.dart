import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'language_service.dart';
import 'doctor_avatar.dart';
import 'widgets/dark_mode_toggle.dart';

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

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _loading) return;
    _controller.clear();

    setState(() {
      _messages.add({'role': 'user', 'text': text});
      _loading = true;
    });
    _scrollToBottom();

    await _getAIResponse(text);
  }

  static const String _groqSystemPrompt = 'You are SoleMate, a medical AI assistant specialized in diabetic foot care. '
      'Answer in the SAME LANGUAGE the user writes to you (Arabic, English, or French). '
      'Keep answers concise, direct, and natural. Do NOT use markdown, bold, asterisks, or bullet points. '
      'Answer exactly what is asked. If they ask for a number, give the number. '
      'If they ask about symptoms, list them simply. '
      'Mention StepGuard features when relevant. '
      'Be compassionate and accurate. For emergencies, advise seeking immediate medical attention.';

  Future<void> _getAIResponse(String userMessage) async {
    try {
      final groqKey = ApiConfig.groqApiKey;
      if (groqKey.isEmpty || groqKey == 'YOUR_GROQ_API_KEY') {
        setState(() {
          _messages.add({'role': 'model', 'text': 'Groq API key not configured. Add it in api_config.dart.'});
          _loading = false;
        });
        _scrollToBottom();
        return;
      }

      final messages = <Map<String, String>>[
        {'role': 'system', 'content': _groqSystemPrompt},
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

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final aiText = body['choices']?[0]?['message']?['content'] ?? 'No response.';
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
              color: Colors.grey.shade300,
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
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: isRTL ? const Radius.circular(16) : const Radius.circular(4),
                  topRight: isRTL ? const Radius.circular(4) : const Radius.circular(16),
                  bottomLeft: const Radius.circular(16),
                  bottomRight: const Radius.circular(16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
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
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: isRTL ? const Radius.circular(16) : const Radius.circular(4),
                topRight: isRTL ? const Radius.circular(4) : const Radius.circular(16),
                bottomLeft: const Radius.circular(16),
                bottomRight: const Radius.circular(16),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
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
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
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
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
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
                fillColor: Colors.grey.shade100,
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
