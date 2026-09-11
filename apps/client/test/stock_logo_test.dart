import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:india_trading_app/widgets/stock_logo.dart';

void main() {
  testWidgets('failed network logo reports failure for market filtering', (
    tester,
  ) async {
    var failed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StockLogo(
            symbol: 'MISSING',
            logoUrl: 'https://example.invalid/logo.png',
            onLoadFailed: () => failed = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(failed, isTrue);
    expect(find.text('MI'), findsNothing);
  });
  testWidgets('unknown stock has a readable code placeholder', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: StockLogo(symbol: ' abc-new ', size: 24)),
      ),
    );
    expect(find.text('AB'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('empty code is handled without crashing', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: StockLogo(symbol: '')),
      ),
    );
    expect(find.text('?'), findsOneWidget);
  });
}
