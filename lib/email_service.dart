import 'dart:math';
import 'package:http/http.dart' as http;
import 'dart:convert';

class EmailService {
  static const String _publicKey = 'rcNuIEFYESgNfV2XH';
  static const String _serviceId = 'service_s5zsztd';
  static const String _templateId = 'template_4a9ajg5';

  static String generateOtp() {
    final rng = Random();
    return (rng.nextInt(900000) + 100000).toString();
  }

  static bool get isConfigured =>
      _publicKey.isNotEmpty && _serviceId.isNotEmpty && _templateId.isNotEmpty;

  static Future<void> sendOtpEmail(String email, String otp) async {
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
    );
    if (response.statusCode != 200) {
      throw Exception('EmailJS error: ${response.statusCode} ${response.body}');
    }
  }
}
