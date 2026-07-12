import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';
import 'forgot_password_screen.dart';
import 'route_transition.dart';
import 'language_service.dart';

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
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);
      await _saveAndGo(email);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
        try {
          await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: password);
          await _saveAndGo(email);
        } on FirebaseAuthException catch (e2) {
          setState(() => _loading = false);
          if (e2.code == 'email-already-in-use') {
            _showSnack(LanguageService.t('login_wrong_password'));
          } else {
            _showSnack(e2.message ?? LanguageService.t('login_create_account_error'));
          }
        }
      } else if (e.code == 'wrong-password') {
        setState(() => _loading = false);
        _showSnack(LanguageService.t('login_wrong_password'));
      } else {
        setState(() => _loading = false);
        _showSnack(e.message ?? LanguageService.t('general_error'));
      }
    } catch (e) {
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
                  decoration: BoxDecoration(color: Colors.teal, borderRadius: BorderRadius.circular(45)),
                  child: const Icon(Icons.person, color: Colors.white, size: 56),
                ),
                const SizedBox(height: 24),
                Text(LanguageService.t('login_title'), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(LanguageService.t('login_subtitle'), style: const TextStyle(fontSize: 14, color: Colors.grey)),
                const SizedBox(height: 32),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: LanguageService.t('email_label'),
                    hintText: LanguageService.t('email_hint'),
                    prefixIcon: const Icon(Icons.email, color: Colors.teal),
                    filled: true, fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
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
                    prefixIcon: const Icon(Icons.lock, color: Colors.teal),
                    filled: true, fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
                    child: Text(LanguageService.t('forgot_password'),
                        style: TextStyle(color: Colors.teal.shade700, fontSize: 13)),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _loginWithEmail,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
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
