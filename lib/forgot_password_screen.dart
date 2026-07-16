import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';
import 'route_transition.dart';
import 'email_service.dart';
import 'language_service.dart';
import 'connectivity_service.dart';
import 'widgets/dark_mode_toggle.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final emailController = TextEditingController();
  final otpController = TextEditingController();
  bool _loading = false;
  bool _otpSent = false;
  String _otpCode = '';
  String _email = '';
  int _cooldownSeconds = 0;
  Timer? _timer;

  static const int _cooldownDuration = 60;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _sendOtp() async {
    final email = emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showSnack(LanguageService.t('forgot_email_empty'));
      return;
    }
    if (!await ConnectivityService.check()) {
      _showSnack(LanguageService.t('offline_desc'));
      return;
    }
    setState(() => _loading = true);
    try {
      _otpCode = EmailService.generateOtp();
      final messageId = await EmailService.sendOtpEmail(email, _otpCode);
      if (!mounted) return;
      _email = email;
      setState(() { _otpSent = true; _loading = false; });
      _showSnack('${LanguageService.t('forgot_otp_sent')} $email');
      _startCooldown();
      if (kDebugMode) debugPrint('OTP email sent, messageId: $messageId');
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      if (e.toString().contains('Vercel')) {
        _showSnack(LanguageService.t('forgot_otp_send_failed'));
      } else {
        _showSnack('${LanguageService.t('network_error')}: $e');
      }
    }
  }

  Future<void> _resendOtp() async {
    final email = _email;
    if (email.isEmpty) return;
    if (!await ConnectivityService.check()) {
      _showSnack(LanguageService.t('offline_desc'));
      return;
    }
    setState(() => _loading = true);
    try {
      _otpCode = EmailService.generateOtp();
      final messageId = await EmailService.sendOtpEmail(email, _otpCode);
      if (!mounted) return;
      setState(() => _loading = false);
      otpController.clear();
      _showSnack('${LanguageService.t('forgot_otp_sent')} $email');
      _startCooldown();
      if (kDebugMode) debugPrint('OTP resent, new messageId: $messageId');
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      if (e.toString().contains('Vercel')) {
        _showSnack(LanguageService.t('forgot_otp_send_failed'));
      } else {
        _showSnack('${LanguageService.t('network_error')}: $e');
      }
    }
  }

  void _startCooldown() {
    _timer?.cancel();
    _cooldownSeconds = _cooldownDuration;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        _cooldownSeconds--;
        if (_cooldownSeconds <= 0) {
          _cooldownSeconds = 0;
          t.cancel();
        }
      });
    });
  }

  Future<void> _verifyOtp() async {
    final otp = otpController.text.trim();
    if (otp.isEmpty) { _showSnack(LanguageService.t('forgot_otp_empty')); return; }
    if (otp != _otpCode) { _showSnack(LanguageService.t('forgot_otp_wrong')); return; }
    setState(() => _loading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('email', _email);
      await prefs.setBool('is_logged_in', true);
      if (mounted) pushReplacementPage(context, const HomeScreen());
    } catch (_) {
      if (mounted) _showSnack(LanguageService.t('network_error'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void dispose() {
    _timer?.cancel();
    emailController.dispose();
    otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.primaryContainer,
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: cs.primary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [const DarkModeToggle()],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 90, height: 90,
                  decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(45)),
                  child: const Icon(Icons.lock_reset, color: Colors.white, size: 48),
                ),
                const SizedBox(height: 24),
                Text(LanguageService.t('forgot_password_title'), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(LanguageService.t(_otpSent ? 'forgot_password_subtitle_otp' : 'forgot_password_subtitle_send'),
                    style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant)),
                const SizedBox(height: 32),
                if (!_otpSent) ...[
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: LanguageService.t('email_label'),
                      hintText: LanguageService.t('email_hint'),
                      prefixIcon: Icon(Icons.email, color: cs.primary),
                      filled: true, fillColor: cs.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: cs.outline),
                      ),
                    ),
                  ),
                ] else ...[
                  TextField(
                    controller: otpController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: LanguageService.t('otp_label'),
                      hintText: LanguageService.t('otp_hint'),
                      prefixIcon: Icon(Icons.lock, color: cs.primary),
                      filled: true, fillColor: cs.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: cs.outline),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : (_otpSent ? _verifyOtp : _sendOtp),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cs.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _loading
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(_otpSent ? LanguageService.t('login_button') : LanguageService.t('forgot_send_code'), style: const TextStyle(fontSize: 18)),
                  ),
                ),
                if (_otpSent) ...[
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: _cooldownSeconds > 0 || _loading ? null : _resendOtp,
                    child: Text(
                      _cooldownSeconds > 0
                          ? LanguageService.t('forgot_resend_in').replaceFirst('%s', '$_cooldownSeconds')
                          : LanguageService.t('forgot_resend_code'),
                      style: TextStyle(
                        fontSize: 14,
                        color: _cooldownSeconds > 0 ? cs.onSurfaceVariant : cs.primary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
