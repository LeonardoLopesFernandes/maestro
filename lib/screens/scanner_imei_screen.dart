import 'package:flutter/material.dart';
import '../utils/constants.dart';

class ScannerImeiScreen extends StatefulWidget {
  const ScannerImeiScreen({super.key});

  @override
  State<ScannerImeiScreen> createState() => _ScannerImeiScreenState();
}

class _ScannerImeiScreenState extends State<ScannerImeiScreen> {
  final TextEditingController _c = TextEditingController();

  String _limpar(String v) => v.replaceAll(RegExp(r'[^0-9]'), '');

  void _confirmar() {
    final imei = _limpar(_c.text);
    if (imei.length < 15) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('IMEI inválido: são necessários ao menos 15 dígitos')),
      );
      return;
    }
    Navigator.of(context).pop(imei.substring(0, 15));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(Constants.RED_600),
        title: const Text('Scanner IMEI'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                'Capture o IMEI do smartphone. O app Kotlin lê um IMEI por vez '
                'e preenche o próximo campo vazio. (Entrada manual espelha o fallback.)',
                style: TextStyle(color: Color(Constants.GRAY_400))),
            const SizedBox(height: 12),
            TextField(
              controller: _c,
              decoration: const InputDecoration(labelText: 'IMEI'),
              keyboardType: TextInputType.number,
              onSubmitted: (_) => _confirmar(),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(Constants.GREEN_500)),
                onPressed: _confirmar,
                child: const Text('Confirmar IMEI',
                    style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
