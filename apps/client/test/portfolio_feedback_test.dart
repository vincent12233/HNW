import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:india_trading_app/pages/product_portfolio_page.dart';

void main() {
  Widget screen(Future<Map<String, dynamic>> Function(String) loader) =>
      MaterialApp(
        home: Scaffold(
          body: ProductPortfolioPage(
            loader: loader,
            onExplore: () {},
            onNotifications: () {},
          ),
        ),
      );

  testWidgets(
    'loading has a message and failure offers retry without fake balances',
    (tester) async {
      final response = Completer<Map<String, dynamic>>();
      await tester.pumpWidget(screen((_) => response.future));
      expect(find.text('Loading portfolio'), findsOneWidget);
      expect(find.text('Total Portfolio Value'), findsNothing);
      response.completeError(Exception('offline'));
      await tester.pumpAndSettle();
      expect(find.text('Unable to load portfolio'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Total Portfolio Value'), findsNothing);
    },
  );

  testWidgets('failed refresh preserves the previous portfolio and labels it', (
    tester,
  ) async {
    var requests = 0;
    await tester.pumpWidget(
      screen((_) async {
        if (++requests > 1) throw Exception('offline');
        return {
          'positionCount': 0,
          'currentValue': 1200,
          'totalPnl': 0,
          'categories': [],
          'history': {'points': []},
        };
      }),
    );
    await tester.pumpAndSettle();
    expect(find.text('Total Portfolio Value'), findsOneWidget);
    await tester.tap(find.byTooltip('Refresh'));
    await tester.pumpAndSettle();
    expect(find.text('Total Portfolio Value'), findsOneWidget);
    expect(
      find.text('Showing previously loaded portfolio data.'),
      findsOneWidget,
    );
    expect(find.text('Unable to load portfolio'), findsNothing);
  });
}
