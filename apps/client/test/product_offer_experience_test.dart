import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:india_trading_app/theme/app_theme.dart';
import 'package:india_trading_app/widgets/trading/product_offer_card.dart';
import 'package:india_trading_app/widgets/trading/product_risk_notice.dart';

void main() {
  testWidgets('product offer remains readable with large text', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: MediaQuery(
        data: const MediaQueryData(size: Size(320, 568), textScaler: TextScaler.linear(1.5)),
        child: Scaffold(
          body: ListView(children: [
            ProductOfferCard(
              name: 'Orient Cables Limited',
              symbol: 'ORIENT',
              type: 'IPO',
              marketPrice: 126,
              offerPrice: 100,
              expectedReturn: 26,
              onTrade: () {},
            ),
          ]),
        ),
      ),
    ));

    expect(find.text('Expected return'), findsOneWidget);
    expect(find.text('Trade Now'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('product confirmations expose the shared risk notice', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: const Scaffold(body: ProductRiskNotice()),
    ));
    expect(find.textContaining('not guaranteed outcomes'), findsOneWidget);
  });
}
