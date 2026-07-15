import 'dart:async';
import 'package:flutter/material.dart';
import 'language_service.dart';
import 'doctor_avatar.dart';
import 'widgets/dark_mode_toggle.dart';

class TipsScreen extends StatefulWidget {
  const TipsScreen({super.key});

  @override
  State<TipsScreen> createState() => _TipsScreenState();
}

class _TipsScreenState extends State<TipsScreen> {
  final List<Map<String, dynamic>> tips = [
    {
      'icon': Icons.do_not_step,
      'titleKey': 'tip_1_title',
      'descKey': 'tip_1_desc',
      'color': Colors.red,
    },
    {
      'icon': Icons.search,
      'titleKey': 'tip_2_title',
      'descKey': 'tip_2_desc',
      'color': Colors.orange,
    },
    {
      'icon': Icons.water_drop,
      'titleKey': 'tip_3_title',
      'descKey': 'tip_3_desc',
      'color': Colors.blue,
    },
    {
      'icon': Icons.content_cut,
      'titleKey': 'tip_4_title',
      'descKey': 'tip_4_desc',
      'color': Colors.blue,
    },
    {
      'icon': Icons.visibility,
      'titleKey': 'tip_5_title',
      'descKey': 'tip_5_desc',
      'color': Colors.purple,
    },
    {
      'icon': Icons.local_hospital,
      'titleKey': 'tip_6_title',
      'descKey': 'tip_6_desc',
      'color': Colors.red,
    },
  ];

  bool _showTyping = true;

  @override
  void initState() {
    super.initState();
    LanguageService.currentLang.addListener(_onLangChanged);
    Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _showTyping = false);
    });
  }

  void _onLangChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    LanguageService.currentLang.removeListener(_onLangChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isRTL = LanguageService.isRTL;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.chat, color: Colors.white, size: 22),
            const SizedBox(width: 8),
            Text(LanguageService.t('prevention_tips')),
          ],
        ),
        centerTitle: true,
        elevation: 0,
        actions: [const DarkModeToggle()],
      ),
      body: Directionality(
        textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 20, 12, 80),
          itemCount: tips.length + 1 + (_showTyping ? 1 : 0),
          itemBuilder: (context, index) {
            int idx = index;
            if (idx == 0) {
              final text = LanguageService.t('ai_chat_greeting');
              return DoctorChatBubble(message: text, isRTL: isRTL);
            }
            idx--;
            if (_showTyping) {
              if (idx == 0) return _buildTypingIndicator(isRTL);
              idx--;
           }
            if (idx >= tips.length) return const SizedBox.shrink();
            final tip = tips[idx];
            return _buildTipMessage(
              isRTL: isRTL,
              title: LanguageService.t(tip['titleKey'] as String),
              description: LanguageService.t(tip['descKey'] as String),
              icon: tip['icon'] as IconData,
              color: tip['color'] as Color,
            );
          },
        ),
      ),
    );
  }

  Widget _buildTypingIndicator(bool isRTL) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DoctorAvatar(),
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
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: _TypingDots(),
          ),
        ],
      ),
    );
  }

  Widget _buildTipMessage({
    required bool isRTL,
    required String title,
    required String description,
    required IconData icon,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DoctorAvatar(),
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
                border: BorderDirectional(
                  start: BorderSide(color: color, width: 3),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, size: 18, color: color),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final delay = i * 0.2;
            final t = (_controller.value - delay).clamp(0.0, 1.0);
            final bounce = (t < 0.5) ? 2 * t : 2 * (1 - t);
            return Padding(
              padding: EdgeInsetsDirectional.only(end: i < 2 ? 4 : 0),
              child: Transform.translate(
                offset: Offset(0, -bounce * 4),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
