import 'package:flutter/material.dart';
import 'language_service.dart';

class ErrorHandler {
  static void showSnackBar(BuildContext context, dynamic error) {
    final msg = error is String
        ? error
        : error is Exception
            ? error.toString()
            : LanguageService.t('network_error');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: LanguageService.t('ok'),
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  static Future<T?> guard<T>(BuildContext context, Future<T> Function() fn) async {
    try {
      return await fn();
    } catch (e) {
      showSnackBar(context, e);
      return null;
    }
  }

  static Widget loadingWidget({String? message}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          if (message != null) ...[
            const SizedBox(height: 12),
            Text(message, style: const TextStyle(color: Colors.grey)),
          ],
        ],
      ),
    );
  }

  static Widget skeleton({int lines = 3}) {
    return Column(
      children: List.generate(lines, (i) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
        child: Container(
          height: 16,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      )),
    );
  }
}
