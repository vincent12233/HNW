import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:india_trading_app/models/portfolio_position.dart';
import 'package:india_trading_app/widgets/trading/holdings_tab.dart';

void main() {
  for (final width in [320.0, 375.0, 430.0]) {
    testWidgets('large holdings fit $width with enlarged text and no logo', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.6)),
            child: child!,
          ),
          home: Scaffold(
            body: HoldingsTab(
              positions: const {
                'BSE:LONGSYMBOL': PortfolioPosition(
                  symbol: 'LONGSYMBOL',
                  name: 'A very long company name for responsive display',
                  category: 'EQUITY',
                  quantity: 9999999,
                  averageCost: 123456.78,
                  exchange: 'BSE',
                ),
              },
              stocks: const [],
              onStockTap: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('LONGSYMBOL'), findsOneWidget);
      expect(find.text('BSE'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
