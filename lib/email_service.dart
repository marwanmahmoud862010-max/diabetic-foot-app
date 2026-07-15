import 'dart:math';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class EmailService {
  static String get _publicKey => dotenv.env['EMAILJS_PUBLIC_KEY'] ?? '';
  static String get _serviceId => dotenv.env['EMAILJS_SERVICE_ID'] ?? '';
  static String get _templateId => dotenv.env['EMAILJS_TEMPLATE_ID'] ?? '';

  static String generateOtp() {
    final rng = Random.secure();
    return (rng.nextInt(900000) + 100000).toString();
  }

  static bool get isConfigured =>
      _publicKey.isNotEmpty && _serviceId.isNotEmpty && _templateId.isNotEmpty;

  static Future<void> sendOtpEmail(String email, String otp) async {
    if (!isConfigured) {
      throw Exception('EmailJS is not configured. Check .env file.');
    }
    final uri = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');
    final body = {
      'service_id': _serviceId,
      'template_id': _templateId,
      'user_id': _publicKey,
      'template_params': {
        'email': email,
        'passcode': otp,
        'time': DateTime.now().add(const Duration(minutes: 15)).toString().substring(11, 16),
      },
    };
    final response = await http.post(
      uri,
      body: jsonEncode(body),
      headers: {'Content-Type': 'application/json'},
    ).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('EmailJS (${response.statusCode}): ${response.body}');
    }
  }
}