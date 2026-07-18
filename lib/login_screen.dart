import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  bool _obscurePassword = true;

  bool get _isFormValid => emailController.text.trim().isNotEmpty && passwordController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    emailController.addListener(_onFieldChanged);
    passwordController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    setState(() {});
  }

  Future<void> _loginWithEmail() async {
    if (!_isFormValid) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    if (!await ConnectivityService.check()) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showSnack(LanguageService.t('offline_desc'));
      return;
    }

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
      if (!mounted) return;
      pushReplacementPage(context, const HomeScreen());
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        try {
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
            email: emailController.text.trim(),
            password: passwordController.text.trim(),
          );
          if (!mounted) return;
          pushReplacementPage(context, const HomeScreen());
        } on FirebaseAuthException catch (e2) {
          if (!mounted) return;
          setState(() => _loading = false);
          if (e2.code == 'email-already-in-use') {
            _showSnack(LanguageService.t('login_wrong_password'));
          } else {
            _showSnack(_friendlyError(e2));
          }
        }
      } else {
        if (!mounted) return;
        setState(() => _loading = false);
        _showSnack(_friendlyError(e));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showSnack(LanguageService.t('network_error'));
    }
  }

  String _friendlyError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'invalid-email':
        return LanguageService.t('login_wrong_password');
      case 'too-many-requests':
        return LanguageService.t('login_too_many_requests');
      case 'weak-password':
        return LanguageService.t('login_weak_password');
      default:
        return e.message ?? LanguageService.t('login_error_generic');
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void dispose() {
    emailController.removeListener(_onFieldChanged);
    passwordController.removeListener(_onFieldChanged);
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.primaryContainer,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 90, height: 90,
                    decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(45)),
                    child: const Icon(Icons.person, color: Colors.white, size: 56),
                  ),
                  const SizedBox(height: 24),
                  Text(LanguageService.t('login_title'), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(LanguageService.t('login_subtitle'), style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant)),
                  const SizedBox(height: 32),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    textInputAction: TextInputAction.next,
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
                  const SizedBox(height: 16),
                  TextField(
                    controller: passwordController,
                    obscureText: _obscurePassword,
                    autofillHints: const [AutofillHints.password],
                    textInputAction: TextInputAction.done,
                    onSubmitted: _loading ? null : (_) => _loginWithEmail(),
                    decoration: InputDecoration(
                      labelText: LanguageService.t('password_label'),
                      hintText: LanguageService.t('password_hint'),
                      prefixIcon: Icon(Icons.lock, color: cs.primary),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off : Icons.visibility,
                          color: cs.onSurfaceVariant,
                        ),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                      filled: true, fillColor: cs.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: cs.outline),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton(
                      onPressed: () => pushPage(context, const ForgotPasswordScreen()),
                      child: Text(LanguageService.t('forgot_password'),
                          style: TextStyle(color: cs.primary, fontSize: 13)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading || !_isFormValid ? null : _loginWithEmail,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: cs.primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: cs.primary.withValues(alpha: 0.4),
                        disabledForegroundColor: Colors.white60,
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
      ),
    );
  }
}
