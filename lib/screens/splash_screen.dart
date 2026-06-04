import 'package:flutter/material.dart';
import 'package:mortality_analysis/main.dart';
import 'dart:async';
// ⚠ Replace with the exact filename of your Sign Up screen

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
 @override
void initState() {
  super.initState();
  // Wait 3 seconds, then evaluate authentication routing automatically
  Timer(const Duration(seconds: 3), () {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => MyApp.getHomeScreen(), // Calls your session manager from main.dart
      ),
    );
  });
}
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Matches the dark dashboard background
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // THE LOGO (Completely text-free)
            SizedBox(
              width: 120,
              height: 120,
              child: CustomPaint(
                painter: MortalityLogoPainter(),
              ),
            ),
            const SizedBox(height: 40),
            // Minimalist Loading Indicator
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF38BDF8)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  THE LOGOMARK PAINTER (Circle + Data Pulse Line)
// ═══════════════════════════════════════════════════════
class MortalityLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF38BDF8) // Accent cyan blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    final path = Path();
    
    // Smooth geometrical pulse path drawing left-to-right
    path.moveTo(size.width * 0.1, size.height * 0.6);
    path.lineTo(size.width * 0.3, size.height * 0.6);
    path.lineTo(size.width * 0.4, size.height * 0.3); // Peak spike
    path.lineTo(size.width * 0.5, size.height * 0.8); // Valley drop
    path.lineTo(size.width * 0.6, size.height * 0.5); // Baseline recovery
    path.lineTo(size.width * 0.9, size.height * 0.5); // Linear tracking

    // The surrounding subtle circular target line
    final circlePaint = Paint()
      ..color = const Color(0xFF38BDF8).withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), size.width * 0.45, circlePaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}