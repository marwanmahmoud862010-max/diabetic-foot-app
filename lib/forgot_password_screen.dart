import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';
import 'route_transition.dart';
import 'email_service.dart';
import 'language_service.dart';

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
      _showSnack('برجاء إدخال إيميل صحيح');
      return;
    }
    setState(() => _loading = true);
    try {
      _otpCode = EmailService.generateOtp();
      await EmailService.sendOtpEmail(email, _otpCode);
      _email = email;
      setState(() { _otpSent = true; _loading = false; });
      _showSnack('تم إرسال الكود إلى $email');
    } catch (e) {
      setState(() => _loading = false);
      _showSnack(e.toString());
    }
  }

  Future<void> _verifyOtp() async {
    final otp = otpController.text.trim();
    if (otp.isEmpty) { _showSnack('برجاء إدخال الكود'); return; }
    if (otp != _otpCode) { _showSnack('الكود غير صحيح'); return; }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('email', _email);
    await prefs.setBool('is_logged_in', true);
    if (mounted) pushReplacementPage(context, const HomeScreen());
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
      backgroundColor: Colors.teal.shade50,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.teal),
          onPressed: () => Navigator.pop(context),
        ),
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
                  decoration: BoxDecoration(color: Colors.teal, borderRadius: BorderRadius.circular(45)),
                  child: const Icon(Icons.lock_reset, color: Colors.white, size: 48),
                ),
                const SizedBox(height: 24),
                Text('نسيت الباسوورد', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(_otpSent ? 'أدخل الكود المرسل إلى بريدك' : 'أدخل إيميلك لاستعادة الحساب',
                    style: const TextStyle(fontSize: 14, color: Colors.grey)),
                const SizedBox(height: 32),
                if (!_otpSent) ...[
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
                ] else ...[
                  TextField(
                    controller: otpController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'OTP',
                      hintText: 'أدخل الكود',
                      prefixIcon: const Icon(Icons.lock, color: Colors.teal),
                      filled: true, fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
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
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _loading
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(_otpSent ? 'تسجيل الدخول' : 'إرسال الكود', style: const TextStyle(fontSize: 18)),
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
