import 'package:flutter/material.dart';

import '../network/session_manager.dart';
import '../widgets/maestro_logo_draw.dart';

class SplashScreen extends StatefulWidget {
  final SessionManager session;

  const SplashScreen({super.key, required this.session});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _text;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _text = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..forward();
    _opacity = CurvedAnimation(
      parent: _text,
      curve: const Interval(0.45, 1.0, curve: Curves.easeOut),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.35),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _text,
      curve: const Interval(0.45, 1.0, curve: Curves.easeOutCubic),
    ));
    _decide();
  }

  Future<void> _decide() async {
    await Future.delayed(const Duration(milliseconds: 2400));
    if (!mounted) return;
    if (widget.session.isLoggedIn()) {
      Navigator.of(context).pushReplacementNamed('/home');
    } else if (widget.session.hasSavedCredentials()) {
      Navigator.of(context).pushReplacementNamed('/auto-login');
    } else {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE60000),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MaestroLogoDraw(size: 140),
            const SizedBox(height: 6),
            FadeTransition(
              opacity: _opacity,
              child: SlideTransition(
                position: _slide,
                child: const Text(
                  'maestro',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 42,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
