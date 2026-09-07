import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Compact Aadhaar-style identity mark for the document selector.
class AadhaarMark extends StatelessWidget {
  const AadhaarMark({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Aadhaar',
    image: true,
    child: const SizedBox(
      width: 32,
      height: 26,
      child: CustomPaint(painter: _AadhaarMarkPainter()),
    ),
  );
}

class _AadhaarMarkPainter extends CustomPainter {
  const _AadhaarMarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 64, size.height / 52);
    final rays = Paint()
      ..color = const Color(0xFFF6B719)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    const center = Offset(32, 32);
    for (var i = 0; i <= 10; i++) {
      final angle = math.pi + i * math.pi / 10;
      final direction = Offset(math.cos(angle), math.sin(angle));
      canvas.drawLine(center + direction * 23, center + direction * 29, rays);
    }
    final ridge = Paint()
      ..color = const Color(0xFFE52B36)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.3
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 5; i++) {
      final inset = i * 3.7;
      final left = 12 + inset;
      final right = 52 - inset;
      final top = 12 + inset;
      final path = Path()
        ..moveTo(left, 37 - i * 0.5)
        ..cubicTo(left, top + 13, left, top, 32, top)
        ..cubicTo(right, top, right, top + 12, right, 34)
        ..quadraticBezierTo(right, 39, right - 2, 42);
      canvas.drawPath(path, ridge);
    }
    canvas.drawPath(
      Path()
        ..moveTo(32, 30)
        ..cubicTo(32, 34, 32, 39, 28, 43),
      ridge,
    );
    final label = TextPainter(
      text: const TextSpan(
        text: 'AADHAAR',
        style: TextStyle(
          color: Color(0xFFE52B36),
          fontSize: 7,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    label.paint(canvas, Offset((64 - label.width) / 2, 44));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _AadhaarMarkPainter oldDelegate) => false;
}
