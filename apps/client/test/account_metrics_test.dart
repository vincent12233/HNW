import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:india_trading_app/widgets/account_metrics.dart';

void main() {
  testWidgets('first-load failure is distinct from stale confirmed balances', (
    tester,
  ) async {
    var retries = 0;
    Widget screen({required bool hasData, bool refreshing = false}) =>
        MaterialApp(
          home: Scaffold(
            body: AccountDataStatus(
              hasData: hasData,
              refreshing: refreshing,
              failed: true,
              onRetry: () => retries++,
            ),
          ),
        );
    await tester.pumpWidget(screen(hasData: false));
    expect(
      find.text('Balances are unavailable. Please retry.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Retry'));
    expect(retries, 1);
    await tester.pumpWidget(screen(hasData: true));
    expect(
      find.text(
        'Balances could not be refreshed. Showing previously loaded values.',
      ),
      findsOneWidget,
    );
    await tester.pumpWidget(screen(hasData: true, refreshing: true));
    expect(find.text('Retry'), findsNothing);
    expect(find.text('Updating balances…'), findsOneWidget);
  });

  testWidgets('account labels and large values reflow with enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: const Scaffold(
          body: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: AccountMetrics(
              items: [
                AccountMetric('Available Funds', '₹12,345,678.90'),
                AccountMetric('Used Margin', '--'),
                AccountMetric('Unrealized P&L', '-₹98,765.43'),
              ],
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(FittedBox), findsNothing);
    expect(
      tester.getTopLeft(find.text('Margin Used')).dy,
      greaterThan(tester.getBottomLeft(find.text('₹12,345,678.90')).dy),
    );
  });
}
