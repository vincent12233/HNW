import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:india_trading_app/widgets/trading/funds_tab.dart';

void main() {
  testWidgets('failed load is not an empty ledger and supports retry', (
    tester,
  ) async {
    var retries = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FundsTab(
            transactions: const [],
            loadFailed: true,
            onRefresh: () async {
              retries++;
            },
          ),
        ),
      ),
    );
    expect(find.text('No fund transactions'), findsNothing);
    expect(
      find.text('Unable to load account activity. Please try again.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Retry'));
    expect(retries, 1);
  });

  testWidgets('initial loading does not show empty records', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: FundsTab(transactions: [], loading: true)),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('No fund transactions'), findsNothing);
  });
}
