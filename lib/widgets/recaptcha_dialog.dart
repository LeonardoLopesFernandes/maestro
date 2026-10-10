import 'package:flutter/material.dart';

// Simula o reCAPTCHA do Kotlin (RecaptchaManager): ao marcar "Não sou um robô"
// abre um diálogo com o logo do reCAPTCHA + spinner por ~2s e retorna um token
// sintético. O app Kotlin também usa um token sintético (não há Google key real).
class RecaptchaDialog {
  static Future<String?> show(BuildContext context) {
    String? token;
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        Future.delayed(const Duration(seconds: 2), () {
          if (Navigator.of(ctx).canPop()) {
            token = 'synthetic_recaptcha_${DateTime.now().millisecondsSinceEpoch}';
            Navigator.of(ctx).pop(token);
          }
        });
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          contentPadding: const EdgeInsets.all(24),
          content: SizedBox(
            width: double.infinity,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/icons/ic_recaptcha_logo.webp', height: 44),
                const SizedBox(height: 18),
                const CircularProgressIndicator(color: Color(0xFF12CD0C)),
                const SizedBox(height: 14),
                const Text('Verificando que você não é um robô...',
                    style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                    textAlign: TextAlign.center),
              ],
            ),
          ),
        );
      },
    );
  }
}
