import 'dart:math' as math;

import 'package:flutter/material.dart';

class MiniLineChartPainter extends CustomPainter {
  const MiniLineChartPainter({
    required this.color,
    this.values = const <double>[],
  });

  final Color color;
  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final source = values;
    final minimum = source.reduce((left, right) => math.min(left, right));
    final maximum = source.reduce((left, right) => math.max(left, right));
    final spread = math
        .max(math.max(maximum - minimum, maximum.abs() * .01), .000001)
        .toDouble();
    final normalized = source
        .map((value) => .88 - ((value - minimum) / spread) * .76)
        .toList(growable: false);
    final line = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: .22), color.withValues(alpha: 0)],
      ).createShader(Offset.zero & size);
    final path = Path();
    for (var index = 0; index < normalized.length; index++) {
      final point = Offset(
        size.width * index / (normalized.length - 1),
        size.height * normalized[index],
      );
      if (index == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    final area = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(area, fill);
    canvas.drawPath(path, line);
  }

  @override
  bool shouldRepaint(covariant MiniLineChartPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.values != values;
}
