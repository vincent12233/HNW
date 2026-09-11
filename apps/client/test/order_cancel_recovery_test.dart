import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:india_trading_app/models/trading_order.dart';
import 'package:india_trading_app/widgets/trading/standard_order_details_sheet.dart';

void main() {
  testWidgets('cancel exception restores button without reporting success', (
    tester,
  ) async {
    final order = TradingOrder(
      symbol: 'TEST',
      isBuy: true,
      quantity: 2,
      price: 10,
      status: 'OPEN',
      placedAt: DateTime(2026),
    );
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showStandardOrderDetails(
                context,
                order: order,
                onCancel: (_) async {
                  calls++;
                  throw Exception('offline');
                },
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Cancel Order'));
    await tester.tap(find.text('Cancel Order'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Cancel Order'));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.text('Cancelling...'), findsNothing);
    expect(find.text('TEST order cancelled'), findsNothing);
    expect(
      find.text(
        'Unable to confirm cancellation. Refresh your orders to check the latest status.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
