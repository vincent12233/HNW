import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:india_trading_app/widgets/market_status_card.dart';

void main() {
  testWidgets('unknown server state is not presented as open or closed', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: MarketStatusCard())),
    );
    expect(find.text('Market status unavailable'), findsOneWidget);
    expect(find.text('NSE Open'), findsNothing);
    expect(find.text('NSE Closed'), findsNothing);
  });

  testWidgets('server session and quote connection are distinct states', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MarketStatusCard(isOpen: true, quotesConnected: false),
        ),
      ),
    );
    expect(find.text('NSE Open'), findsOneWidget);
    expect(
      find.text('Live quotes reconnecting. Prices may be delayed.'),
      findsOneWidget,
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MarketStatusCard(isOpen: false, quotesConnected: true),
        ),
      ),
    );
    expect(find.text('NSE Closed'), findsOneWidget);
    expect(
      find.text('Live quotes reconnecting. Prices may be delayed.'),
      findsNothing,
    );
  });

  testWidgets(
    'unknown and disconnected status fit large text on a small phone',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
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
            body: Padding(
              padding: EdgeInsets.all(16),
              child: MarketStatusCard(quotesConnected: false),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
