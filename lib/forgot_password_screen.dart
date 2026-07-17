import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  bool _loading = false;
  bool _done = false;

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetEmail() async {
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
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      setState(() { _loading = false; _done = true; });
      _showSnack(LanguageService.t('forgot_password_email_sent'));
    } on FirebaseAuthException catch (e) {
      setState(() => _loading = false);
      String msg;
      switch (e.code) {
        case 'invalid-email':
          msg = LanguageService.t('forgot_email_empty');
          break;
        case 'user-not-found':
          msg = LanguageService.t('forgot_user_not_found');
          break;
        case 'network-request-failed':
          msg = LanguageService.t('network_error');
          break;
        default:
          msg = LanguageService.t('forgot_email_failed');
      }
      _showSnack(msg);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showSnack(LanguageService.t('network_error'));
    }
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
                Text(
                  LanguageService.t(_done ? 'forgot_password_subtitle_done' : 'forgot_password_subtitle_send'),
                  style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  enabled: !_loading,
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
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading || _done ? null : _sendResetEmail,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cs.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _loading
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(_done
                            ? LanguageService.t('forgot_send_again')
                            : LanguageService.t('forgot_send_code'),
                            style: const TextStyle(fontSize: 18)),
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
