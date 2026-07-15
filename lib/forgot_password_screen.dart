import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';
import 'route_transition.dart';
import 'email_service.dart';
import 'language_service.dart';
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

  Future<void> _sendOtp() async {
    final email = emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showSnack(LanguageService.t('forgot_email_empty'));
      return;
    }
    setState(() => _loading = true);
    try {
      _otpCode = EmailService.generateOtp();
      await EmailService.sendOtpEmail(email, _otpCode);
      if (!mounted) return;
      _email = email;
      setState(() { _otpSent = true; _loading = false; });
      _showSnack('${LanguageService.t('forgot_otp_sent')} $email');
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showSnack(LanguageService.t('network_error'));
    }
  }

  Future<void> _verifyOtp() async {
    final otp = otpController.text.trim();
    if (otp.isEmpty) { _showSnack(LanguageService.t('forgot_otp_empty')); return; }
    if (otp != _otpCode) { _showSnack(LanguageService.t('forgot_otp_wrong')); return; }
    setState(() => _loading = true);
    try {
      final randomPass = '${Random().nextInt(99999999)}StepGuard${Random().nextInt(9999)}';
      await FirebaseAuth.instance.createUserWithEmailAndPassword(email: _email, password: randomPass);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('email', _email);
      await prefs.setBool('is_logged_in', true);
      if (mounted) pushReplacementPage(context, const HomeScreen());
    } on FirebaseAuthException catch (_) {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: _email);
      if (mounted) {
        _showSnack(LanguageService.t('forgot_password_email_sent'));
        Navigator.pop(context);
      }
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
    emailController.dispose();
    otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.primary),
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
                  decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, borderRadius: BorderRadius.circular(45)),
                  child: const Icon(Icons.lock_reset, color: Colors.white, size: 48),
                ),
                const SizedBox(height: 24),
                Text(LanguageService.t('forgot_password_title'), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(LanguageService.t(_otpSent ? 'forgot_password_subtitle_otp' : 'forgot_password_subtitle_send'),
                    style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                const SizedBox(height: 32),
                if (!_otpSent) ...[
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: LanguageService.t('email_label'),
                      hintText: LanguageService.t('email_hint'),
                      prefixIcon: Icon(Icons.email, color: Theme.of(context).colorScheme.primary),
                      filled: true, fillColor: Theme.of(context).colorScheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
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
                      prefixIcon: Icon(Icons.lock, color: Theme.of(context).colorScheme.primary),
                      filled: true, fillColor: Theme.of(context).colorScheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
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
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _loading
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(_otpSent ? LanguageService.t('login_button') : LanguageService.t('forgot_send_code'), style: const TextStyle(fontSize: 18)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
