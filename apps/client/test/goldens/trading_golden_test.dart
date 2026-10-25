import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:india_trading_app/models/stock_quote.dart';
import 'package:india_trading_app/theme/app_theme.dart';
import 'package:india_trading_app/widgets/trading/order_ticket.dart';

void main() {
  testWidgets('protected order ticket visual baseline', (tester) async {
    final quantity = TextEditingController(text: '10');
    final limit = TextEditingController(text: '1450');
    addTearDown(quantity.dispose);
    addTearDown(limit.dispose);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final quote = StockQuote(
      'RELIANCE',
      'Reliance Industries',
      1456,
      1.2,
      12000,
      DateTime(2026, 10, 25, 10, 30),
      bid: 1455.5,
      ask: 1456.5,
      quoteFresh: true,
    );
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('golden'),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: OrderTicketPanel(
                stock: quote,
                isBuy: true,
                orderType: 'LIMIT',
                timeInForce: 'DAY',
                quantityController: quantity,
                limitPriceController: limit,
                onBuyChanged: (_) {},
                onOrderTypeChanged: (_) {},
                onTimeInForceChanged: (_) {},
                onChanged: () {},
                marketOpen: true,
                quotesConnected: true,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const ValueKey('golden')),
      matchesGoldenFile('trading_ticket_390x844.png'),
    );
  });
}
