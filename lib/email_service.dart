import 'dart:math';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class EmailService {
  static String get _vercelUrl => dotenv.env['VERCEL_URL'] ?? '';

  static String generateOtp() {
    final rng = Random.secure();
    return (rng.nextInt(900000) + 100000).toString();
  }

  static bool get isConfigured => _vercelUrl.isNotEmpty;

  static Future<String> sendOtpEmail(String email, String otp) async {
    if (!isConfigured) {
      throw Exception('Vercel URL not configured. Check .env file.');
    }

    final uri = Uri.parse('$_vercelUrl/api/send-otp');
    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email, 'otp': otp}),
        )
        .timeout(const Duration(seconds: 20));

    if (kDebugMode) {
      debugPrint('Vercel response: ${response.statusCode} ${response.body}');
    }

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['success'] == true) {
        final messageId = data['messageId'] as String? ?? 'unknown';
        if (kDebugMode) {
          debugPrint('Vercel messageId: $messageId');
        }
        return messageId;
      }
    }

    throw Exception('Vercel (${response.statusCode}): ${response.body}');
  }
}
