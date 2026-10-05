import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

enum OtpRequestResult { sent, cooldown, userNotFound, invalidEmail, tooManyRequests, failure }

class AuthApiException implements Exception {
  AuthApiException(this.code, {this.statusCode});

  final String code;
  final int? statusCode;

  @override
  String toString() => 'AuthApiException($code, status: $statusCode)';
}

class OtpRequestOutcome {
  OtpRequestOutcome(this.result, {this.retryAfterSeconds});

  final OtpRequestResult result;
  final int? retryAfterSeconds;
}

class AuthApiService {
  static String get baseUrl =>
      (dotenv.env['AUTH_API_BASE_URL'] ?? '').trim().replaceAll(RegExp(r'/+$'), '');

  static bool get isConfigured {
    final uri = Uri.tryParse(baseUrl);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) return false;
    return uri.scheme == 'https' || uri.scheme == 'http';
  }

  static Uri _uri(String path) => Uri.parse('$baseUrl$path');

  static Future<OtpRequestOutcome> requestOtp(String email) async {
    final response = await _post('/api/request-otp', {'email': email});
    if (response['success'] == true) {
      return OtpRequestOutcome(
        response['cooldown'] == true ? OtpRequestResult.cooldown : OtpRequestResult.sent,
      );
    }
    switch (response['error']) {
      case 'user_not_found':
        return OtpRequestOutcome(OtpRequestResult.userNotFound);
      case 'invalid_email':
        return OtpRequestOutcome(OtpRequestResult.invalidEmail);
      case 'too_many_requests':
        return OtpRequestOutcome(OtpRequestResult.tooManyRequests);
      default:
        return OtpRequestOutcome(OtpRequestResult.failure);
    }
  }

  static Future<String> verifyOtp(String email, String otp) async {
    final response = await _post('/api/verify-otp', {'email': email, 'otp': otp});
    if (response['success'] == true && response['resetToken'] is String) {
      return response['resetToken'] as String;
    }
    throw AuthApiException(
      '${response['error'] ?? 'server_error'}',
      statusCode: response['_status'] as int?,
    );
  }

  static Future<void> confirmReset({
    required String email,
    required String password,
    required String resetToken,
  }) async {
    final response = await _post('/api/confirm-reset', {
      'email': email,
      'password': password,
      'resetToken': resetToken,
    });
    if (response['success'] == true) return;
    throw AuthApiException(
      '${response['error'] ?? 'server_error'}',
      statusCode: response['_status'] as int?,
    );
  }

  static Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> payload) async {
    if (!isConfigured) {
      throw AuthApiException('api_not_configured');
    }
    final http.Response response;
    try {
      response = await http
          .post(
            _uri(path),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 35));
    } catch (_) {
      throw AuthApiException('network_error');
    }

    Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      decoded = <String, dynamic>{};
    }
    decoded['_status'] = response.statusCode;

    if (kDebugMode) {
      debugPrint('[AuthApi] $path -> ${response.statusCode} ${response.body}');
    }
    return decoded;
  }
}