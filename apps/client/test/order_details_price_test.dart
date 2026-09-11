import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:india_trading_app/models/trading_order.dart';
import 'package:india_trading_app/widgets/trading/standard_order_details_sheet.dart';
import 'package:india_trading_app/utils/number_formatters.dart';

void main() {
  for (final filled in [0, 2]) {
    testWidgets('average price uses executions only: $filled filled', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final order = TradingOrder(
        symbol: 'LONGSYMBOL',
        orderId: 'very-long-order-reference-123456789',
        isBuy: true,
        quantity: 10,
        filledQuantity: filled,
        price: 100,
        limitPrice: 110,
        averageFillPrice: filled > 0 ? 105 : null,
        type: 'LIMIT',
        status: 'OPEN',
        placedAt: DateTime(2026),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () =>
                    showStandardOrderDetails(context, order: order),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text(formatPrice(100)), findsNothing);
      expect(
        filled > 0 ? find.text(formatPrice(105)) : find.text('--'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
