import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:india_trading_app/pages/account_security_page.dart';
import 'package:india_trading_app/pages/account_content_page.dart';
import 'package:india_trading_app/services/insight_articles_service.dart';
import 'package:india_trading_app/widgets/app_page_scaffold.dart';
import 'package:india_trading_app/widgets/trading/standard_order_details_sheet.dart';
import 'package:india_trading_app/models/trading_order.dart';
import 'package:india_trading_app/theme/app_theme.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('detail route preserves native back navigation on $platform', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light().copyWith(platform: platform),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AppPageScaffold(
                      appBar: AppBar(title: const Text('Details')),
                      body: const Text('Detail content'),
                    ),
                  ),
                ),
                child: const Text('Open details'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open details'));
      await tester.pumpAndSettle();
      expect(find.text('Detail content'), findsOneWidget);
      if (platform == TargetPlatform.iOS) {
        await tester.dragFrom(const Offset(1, 250), const Offset(700, 0));
      } else {
        await tester.binding.handlePopRoute();
      }
      await tester.pumpAndSettle();
      expect(find.text('Detail content'), findsNothing);
      expect(find.text('Open details'), findsOneWidget);
    });
  }
  const sizes = [
    Size(320, 568),
    Size(360, 640),
    Size(393, 852),
    Size(430, 932),
    Size(844, 390),
  ];
  Widget app(Widget page, {double keyboard = 0}) => MaterialApp(
    theme: AppTheme.light(),
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        padding: const EdgeInsets.only(top: 44, bottom: 34),
        viewPadding: const EdgeInsets.only(top: 44, bottom: 34),
        viewInsets: EdgeInsets.only(bottom: keyboard),
        textScaler: const TextScaler.linear(1.4),
      ),
      child: child!,
    ),
    home: page,
  );
  void viewport(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  for (final size in sizes) {
    testWidgets('password form remains scrollable above keyboard at $size', (
      tester,
    ) async {
      viewport(tester, size);
      await tester.pumpWidget(
        app(
          const AccountSecurityPage(),
          keyboard: size.height < 500 ? 120 : 240,
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byType(FilledButton),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      final button = tester.getRect(find.byType(FilledButton));
      expect(
        button.bottom,
        lessThanOrEqualTo(size.height - (size.height < 500 ? 120 : 240)),
      );
      expect(button.left, greaterThanOrEqualTo(0));
      expect(button.right, lessThanOrEqualTo(size.width));
      expect(tester.takeException(), isNull);
    });
    testWidgets('learning article fits large text at $size', (tester) async {
      viewport(tester, size);
      await tester.pumpWidget(
        app(
          const WealthInsightArticlePage(
            article: InsightArticle(
              id: 'preview',
              slug: 'preview',
              locale: 'en',
              title: 'Account and KYC',
              body: 'Review account and identity information carefully.',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('footer stays above the keyboard and gesture area', (
    tester,
  ) async {
    viewport(tester, const Size(393, 852));
    await tester.pumpWidget(
      app(
        AppPageScaffold(
          appBar: AppBar(title: const Text('Details')),
          body: ListView(children: const [TextField()]),
          bottomNavigationBar: FilledButton(
            onPressed: () {},
            child: const Text('Continue'),
          ),
        ),
        keyboard: 280,
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byType(FilledButton)).bottom,
      lessThanOrEqualTo(852 - 280),
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('long order names and statuses fit on a small phone', (
    tester,
  ) async {
    viewport(tester, const Size(320, 568));
    await tester.pumpWidget(
      app(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showStandardOrderDetails(
                context,
                order: TradingOrder(
                  symbol: 'LONG-INSTITUTIONAL-SYMBOL',
                  isBuy: true,
                  quantity: 1234,
                  filledQuantity: 1000,
                  price: 12345.67,
                  placedAt: DateTime(2026, 9, 10),
                  status: 'PARTIALLY_FILLED',
                  type: 'LIMIT',
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
