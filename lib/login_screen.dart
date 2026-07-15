import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';
import 'forgot_password_screen.dart';
import 'route_transition.dart';
import 'language_service.dart';
import 'connectivity_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool _loading = false;

  Future<void> _loginWithEmail() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    if (email.isEmpty || password.isEmpty) {
      _showSnack(LanguageService.t('login_error_empty'));
      return;
    }
    setState(() => _loading = true);
    if (!await ConnectivityService.check()) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showSnack(LanguageService.t('offline_desc'));
      return;
    }
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);
      await _saveAndGo(email);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        try {
          await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: password);
          await _saveAndGo(email);
        } on FirebaseAuthException catch (e2) {
          if (!mounted) return;
          setState(() => _loading = false);
          if (e2.code == 'email-already-in-use') {
            _showSnack(LanguageService.t('login_wrong_password'));
          } else {
            _showSnack(e2.message ?? LanguageService.t('login_create_account_error'));
          }
        }
      } else {
        if (!mounted) return;
        setState(() => _loading = false);
        _showSnack(e.message ?? LanguageService.t('login_wrong_password'));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showSnack(LanguageService.t('network_error'));
    }
  }

  Future<void> _saveAndGo(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('email', email);
    await prefs.setBool('is_logged_in', true);
    if (mounted) pushReplacementPage(context, const HomeScreen());
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
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
                  child: const Icon(Icons.person, color: Colors.white, size: 56),
                ),
                const SizedBox(height: 24),
                Text(LanguageService.t('login_title'), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(LanguageService.t('login_subtitle'), style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                const SizedBox(height: 32),
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
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: LanguageService.t('password_label'),
                    hintText: LanguageService.t('password_hint'),
                    prefixIcon: Icon(Icons.lock, color: Theme.of(context).colorScheme.primary),
                    filled: true, fillColor: Theme.of(context).colorScheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton(
                    onPressed: () => pushPage(context, const ForgotPasswordScreen()),
                    child: Text(LanguageService.t('forgot_password'),
                        style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 13)),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _loginWithEmail,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _loading
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(LanguageService.t('login_button'), style: const TextStyle(fontSize: 18)),
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
