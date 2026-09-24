import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:india_trading_app/widgets/home/mini_line_chart_painter.dart';

void main() {
  test('mini line chart repaints only when visual data changes', () {
    const original = MiniLineChartPainter(
      color: Colors.blue,
      values: [100, 102, 101],
    );

    expect(
      const MiniLineChartPainter(
        color: Colors.blue,
        values: [100, 102, 101],
      ).shouldRepaint(original),
      isFalse,
    );
    expect(
      const MiniLineChartPainter(
        color: Colors.blue,
        values: [100, 103, 101],
      ).shouldRepaint(original),
      isTrue,
    );
    expect(
      const MiniLineChartPainter(
        color: Colors.red,
        values: [100, 102, 101],
      ).shouldRepaint(original),
      isTrue,
    );
  });
}
