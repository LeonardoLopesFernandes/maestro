import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Leitor de IMEI por câmera, com o mesmo visual do scanner do ml_teste:
/// câmera de trás em tela cheia, área fora da janela escurecida, janela de
/// leitura clara com borda branca, textos e zoom por pinça.
class ScannerImeiScreen extends StatefulWidget {
  const ScannerImeiScreen({super.key});

  @override
  State<ScannerImeiScreen> createState() => _ScannerImeiScreenState();
}

class _ScannerImeiScreenState extends State<ScannerImeiScreen> {
  late final MobileScannerController _controller;
  bool _popped = false;
  double _scaleStart = 1.0;
  double _currentZoom = 1.0;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? _imeiFromRaw(String raw) {
    var digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length == 16 && digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    if (digits.length > 15) digits = digits.substring(0, 15);
    if (digits.length == 14) digits += _luhn(digits);
    return digits.length == 15 ? digits : null;
  }

  String _luhn(String d14) {
    var soma = 0;
    for (var i = 0; i < d14.length; i++) {
      var n = int.parse(d14[d14.length - 1 - i]);
      if (i.isEven) {
        n *= 2;
        if (n > 9) n -= 9;
      }
      soma += n;
    }
    return ((10 - (soma % 10)) % 10).toString();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_popped) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null || raw.isEmpty) continue;
      final imei = _imeiFromRaw(raw);
      if (imei != null) {
        _popped = true;
        Navigator.pop(context, imei);
        return;
      }
    }
  }

  Future<void> _digitar() async {
    final ctrl = TextEditingController();
    final imei = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Digitar IMEI'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'IMEI (15 dígitos)'),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: const Text('OK')),
        ],
      ),
    );
    ctrl.dispose();
    if (imei == null) return;
    final digits = imei.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length >= 15 && mounted) {
      Navigator.pop(context, digits.substring(0, 15));
    }
  }

  void _onScaleStart(ScaleStartDetails details) {
    _scaleStart = _currentZoom;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    final newZoom = (_scaleStart * details.scale).clamp(1.0, 8.0);
    if ((newZoom - _currentZoom).abs() < 0.05) return;
    _currentZoom = newZoom;
    _controller.setZoomScale((_currentZoom - 1) / 7);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onScaleStart: _onScaleStart,
        onScaleUpdate: _onScaleUpdate,
        child: Stack(
          children: [
            MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
              errorBuilder: (context, error, child) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Não foi possível acessar a câmera.\nUse "DIGITAR IMEI".',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 15),
                    ),
                  ),
                );
              },
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: _ScanOverlayPainter()),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                color: Colors.black54,
                padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
                child: const Text(
                  'Aponte para o código de barras do IMEI',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            if (_currentZoom > 1.0)
              Positioned(
                bottom: 120,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_currentZoom.toStringAsFixed(1)}x',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            Positioned(
              bottom: 40,
              left: 16,
              right: 16,
              child: GestureDetector(
                onTap: _digitar,
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Text(
                    'DIGITAR IMEI',
                    style: TextStyle(
                        color: Color(0xFFD7193F),
                        fontSize: 13,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              child: SafeArea(
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width * 0.8,
      height: 140,
    );
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(12));
    final paint = Paint()..color = const Color(0x8C000000);
    final path = Path()
      ..addRect(Offset.zero & size)
      ..addRRect(rrect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, paint);
    final border = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(rrect, border);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
