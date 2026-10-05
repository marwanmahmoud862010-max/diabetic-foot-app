import 'package:flutter/material.dart';

import 'auth_api_service.dart';
import 'connectivity_service.dart';
import 'language_service.dart';
import 'widgets/dark_mode_toggle.dart';
import 'otp_verify_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final emailController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  Future<void> _requestOtp() async {
    final email = emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showSnack(LanguageService.t('forgot_email_empty'));
      return;
    }
    if (!await ConnectivityService.check()) {
      if (!mounted) return;
      _showSnack(LanguageService.t('offline_desc'));
      return;
    }

    setState(() => _loading = true);
    try {
      final outcome = await AuthApiService.requestOtp(email);
      if (!mounted) return;

      switch (outcome.result) {
        case OtpRequestResult.sent:
          _goToOtp(email);
          break;
        case OtpRequestResult.cooldown:
          _showSnack(LanguageService.t('reset_resend_wait'));
          break;
        case OtpRequestResult.userNotFound:
          _showSnack(LanguageService.t('forgot_user_not_found'));
          break;
        case OtpRequestResult.invalidEmail:
          _showSnack(LanguageService.t('forgot_email_empty'));
          break;
        case OtpRequestResult.tooManyRequests:
          _showSnack(LanguageService.t('auth_too_many_requests'));
          break;
        case OtpRequestResult.failure:
          _showSnack(LanguageService.t('forgot_email_failed'));
          break;
      }
    } on AuthApiException catch (e) {
      if (!mounted) return;
      _showSnack(_messageFor(e.code));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _messageFor(String code) {
    switch (code) {
      case 'api_not_configured':
        return LanguageService.t('reset_api_not_configured');
      case 'network_error':
        return LanguageService.t('network_error');
      default:
        return LanguageService.t('forgot_email_failed');
    }
  }

  void _goToOtp(String email) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => OtpVerifyScreen(email: email)),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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
        actions: const [DarkModeToggle()],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: cs.primary,
                    borderRadius: BorderRadius.circular(45),
                  ),
                  child: const Icon(Icons.lock_reset, color: Colors.white, size: 48),
                ),
                const SizedBox(height: 24),
                Text(
                  LanguageService.t('reset_step_email'),
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  LanguageService.t('reset_step_enter'),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.email],
                  enabled: !_loading,
                  onSubmitted: _loading ? null : (_) => _requestOtp(),
                  decoration: InputDecoration(
                    labelText: LanguageService.t('email_label'),
                    hintText: LanguageService.t('email_hint'),
                    prefixIcon: Icon(Icons.email, color: cs.primary),
                    filled: true,
                    fillColor: cs.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: cs.outline),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _requestOtp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cs.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Text(
                            LanguageService.t('reset_send_code'),
                            style: const TextStyle(fontSize: 18),
                          ),
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