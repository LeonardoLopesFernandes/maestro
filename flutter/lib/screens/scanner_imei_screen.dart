import 'package:flutter/material.dart';
import '../utils/constants.dart';

class ScannerImeiScreen extends StatefulWidget {
  const ScannerImeiScreen({super.key});

  @override
  State<ScannerImeiScreen> createState() => _ScannerImeiScreenState();
}

class _ScannerImeiScreenState extends State<ScannerImeiScreen> {
  final List<String> _imeis = [];
  final TextEditingController _c = TextEditingController();

  void _adicionar() {
    final v = _c.text.trim();
    if (v.isNotEmpty) {
      setState(() {
        _imeis.add(v);
        _c.clear();
      });
    }
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
          children: [
            const Text(
                'Capture o IMEI do smartphone. (Entrada manual espelhando o fallback do app Kotlin.)',
                style: TextStyle(color: Color(Constants.GRAY_400))),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _c,
                    decoration:
                        const InputDecoration(labelText: 'IMEI'),
                    keyboardType: TextInputType.number,
                    onSubmitted: (_) => _adicionar(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _adicionar,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: _imeis.length,
                itemBuilder: (_, i) => ListTile(
                  title: Text(_imeis[i]),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () =>
                        setState(() => _imeis.removeAt(i)),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(Constants.GREEN_500)),
                onPressed: _imeis.isEmpty
                    ? null
                    : () => Navigator.of(context).pop(_imeis),
                child: const Text('Confirmar IMEIs',
                    style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
