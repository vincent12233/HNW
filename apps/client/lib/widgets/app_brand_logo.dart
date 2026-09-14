import 'package:flutter/material.dart';

import '../app_config.dart';

class AppBrandLogo extends StatelessWidget {
  const AppBrandLogo({super.key, this.size = 58});

  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: AppConfig.brandGradient,
          borderRadius: BorderRadius.circular(size * .26),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33165DFF),
              blurRadius: 18,
              offset: Offset(0, 7),
            ),
          ],
        ),
        child: CustomPaint(painter: _LogoPainter()),
      );
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = size.width * .055
      ..strokeCap = StrokeCap.round;
    final xs = [size.width * .32, size.width * .50, size.width * .68];
    final tops = [size.height * .29, size.height * .18, size.height * .38];
    final bottoms = [size.height * .72, size.height * .65, size.height * .79];
    final bodyTops = [size.height * .38, size.height * .28, size.height * .48];
    final bodyBottoms = [
      size.height * .62,
      size.height * .53,
      size.height * .68,
    ];
    for (var i = 0; i < xs.length; i++) {
      canvas.drawLine(Offset(xs[i], tops[i]), Offset(xs[i], bottoms[i]), paint);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(
            xs[i] - size.width * .055,
            bodyTops[i],
            xs[i] + size.width * .055,
            bodyBottoms[i],
          ),
          Radius.circular(size.width * .025),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
