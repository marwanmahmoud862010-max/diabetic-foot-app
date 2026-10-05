import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'auth_api_service.dart';
import 'language_service.dart';
import 'set_new_password_screen.dart';
import 'widgets/dark_mode_toggle.dart';

class OtpVerifyScreen extends StatefulWidget {
  const OtpVerifyScreen({super.key, required this.email});

  final String email;

  @override
  State<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends State<OtpVerifyScreen> {
  final otpController = TextEditingController();
  bool _loading = false;
  bool _resending = false;
  int _resendCooldown = 0;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    otpController.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _resendCooldown = 60;
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _resendCooldown -= 1;
        if (_resendCooldown <= 0) {
          _resendCooldown = 0;
          timer.cancel();
        }
      });
    });
  }

  Future<void> _verify() async {
    final otp = otpController.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(otp)) {
      _showSnack(LanguageService.t('reset_otp_wrong'));
      return;
    }

    setState(() => _loading = true);
    try {
      final resetToken = await AuthApiService.verifyOtp(widget.email, otp);
      if (!mounted) return;
      _goToPassword(resetToken);
    } on AuthApiException catch (e) {
      if (!mounted) return;
      _showSnack(_messageFor(e.code));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    if (_resendCooldown > 0 || _resending) return;
    setState(() => _resending = true);
    try {
      final outcome = await AuthApiService.requestOtp(widget.email);
      if (!mounted) return;
      _showSnack(
        outcome.result == OtpRequestResult.cooldown
            ? LanguageService.t('reset_resend_wait')
            : '${LanguageService.t('reset_otp_sent_to')} ${widget.email}',
      );
      if (outcome.result == OtpRequestResult.sent) {
        otpController.clear();
        _startCooldown();
      }
    } on AuthApiException catch (e) {
      if (!mounted) return;
      _showSnack(_messageFor(e.code));
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  String _messageFor(String code) {
    switch (code) {
      case 'otp_incorrect':
      case 'invalid_otp_format':
        return LanguageService.t('reset_otp_wrong');
      case 'otp_expired':
        return LanguageService.t('reset_otp_expired');
      case 'too_many_attempts':
        return LanguageService.t('reset_otp_too_many');
      case 'otp_not_requested':
        return LanguageService.t('reset_otp_not_requested');
      case 'otp_already_verified':
        return LanguageService.t('reset_otp_already_used');
      case 'too_many_requests':
        return LanguageService.t('auth_too_many_requests');
      case 'api_not_configured':
        return LanguageService.t('reset_api_not_configured');
      case 'network_error':
        return LanguageService.t('network_error');
      default:
        return LanguageService.t('reset_otp_wrong');
    }
  }

  void _goToPassword(String resetToken) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => SetNewPasswordScreen(email: widget.email, resetToken: resetToken),
      ),
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
                  child: const Icon(Icons.mark_email_read, color: Colors.white, size: 46),
                ),
                const SizedBox(height: 24),
                Text(
                  LanguageService.t('reset_step_otp'),
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  '${LanguageService.t('reset_otp_hint')}\n${widget.email}',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant, height: 1.5),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: otpController,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  enabled: !_loading,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 26, letterSpacing: 10, fontWeight: FontWeight.bold),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onSubmitted: _loading ? null : (_) => _verify(),
                  decoration: InputDecoration(
                    counterText: '',
                    labelText: LanguageService.t('reset_otp_label'),
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
                    onPressed: _loading ? null : _verify,
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
                            LanguageService.t('reset_otp_verify'),
                            style: const TextStyle(fontSize: 18),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _resendCooldown > 0 || _resending ? null : _resend,
                  child: Text(
                    _resendCooldown > 0
                        ? '${LanguageService.t('reset_otp_resend')} ($_resendCooldown)'
                        : LanguageService.t('reset_otp_resend'),
                    style: TextStyle(color: cs.primary, fontSize: 14),
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