import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'auth_api_service.dart';
import 'connectivity_service.dart';
import 'home_screen.dart';
import 'language_service.dart';
import 'route_transition.dart';
import 'widgets/dark_mode_toggle.dart';

class SetNewPasswordScreen extends StatefulWidget {
  const SetNewPasswordScreen({super.key, required this.email, required this.resetToken});

  final String email;
  final String resetToken;

  @override
  State<SetNewPasswordScreen> createState() => _SetNewPasswordScreenState();
}

class _SetNewPasswordScreenState extends State<SetNewPasswordScreen> {
  final passwordController = TextEditingController();
  final confirmController = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  static const int _minLength = 8;

  @override
  void dispose() {
    passwordController.dispose();
    confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final password = passwordController.text;
    final confirm = confirmController.text;

    if (password.length < _minLength) {
      _showSnack(LanguageService.t('reset_password_short'));
      return;
    }
    if (password != confirm) {
      _showSnack(LanguageService.t('reset_password_mismatch'));
      return;
    }
    if (!await ConnectivityService.check()) {
      if (!mounted) return;
      _showSnack(LanguageService.t('offline_desc'));
      return;
    }

    setState(() => _loading = true);
    try {
      await AuthApiService.confirmReset(
        email: widget.email,
        password: password,
        resetToken: widget.resetToken,
      );

      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: widget.email,
        password: password,
      );

      if (!mounted) return;
      _showSuccessDialog();
    } on AuthApiException catch (e) {
      if (!mounted) return;
      _showSnack(_messageFor(e.code));
    } on FirebaseAuthException {
      if (!mounted) return;
      _showSnack(LanguageService.t('login_invalid_credentials'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _messageFor(String code) {
    switch (code) {
      case 'weak_password':
        return LanguageService.t('reset_password_short');
      case 'invalid_reset_token':
        return LanguageService.t('reset_invalid_token');
      case 'otp_not_requested':
        return LanguageService.t('reset_invalid_token');
      case 'api_not_configured':
        return LanguageService.t('reset_api_not_configured');
      case 'network_error':
        return LanguageService.t('network_error');
      default:
        return LanguageService.t('reset_invalid_token');
    }
  }

  void _showSuccessDialog() {
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: cs.surface,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_circle, color: cs.primary, size: 38),
            ),
            const SizedBox(height: 20),
            Text(
              LanguageService.t('reset_done_title'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              LanguageService.t('reset_done_body'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant, height: 1.4),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              pushReplacementPage(context, const HomeScreen());
            },
            style: FilledButton.styleFrom(
              backgroundColor: cs.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(LanguageService.t('reset_continue')),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  InputDecoration _decoration({
    required String label,
    required String hint,
    required bool hidden,
    required VoidCallback onToggle,
  }) {
    final cs = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(Icons.lock, color: cs.primary),
      suffixIcon: IconButton(
        icon: Icon(
          hidden ? Icons.visibility_off : Icons.visibility,
          color: cs.onSurfaceVariant,
        ),
        onPressed: onToggle,
      ),
      filled: true,
      fillColor: cs.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cs.outline),
      ),
    );
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
                  LanguageService.t('reset_step_password'),
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: passwordController,
                  obscureText: _obscurePassword,
                  enabled: !_loading,
                  textInputAction: TextInputAction.next,
                  decoration: _decoration(
                    label: LanguageService.t('password_label'),
                    hint: LanguageService.t('reset_password_hint'),
hidden: _obscurePassword,
                    onToggle: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: confirmController,
                  obscureText: _obscureConfirm,
                  enabled: !_loading,
                  textInputAction: TextInputAction.done,
                  onSubmitted: _loading ? null : (_) => _submit(),
                  decoration: _decoration(
                    label: LanguageService.t('reset_password_confirm'),
                    hint: LanguageService.t('reset_password_confirm_hint'),
hidden: _obscureConfirm,
                    onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _submit,
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
                            LanguageService.t('reset_step_password'),
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