import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:india_trading_app/models/portfolio_position.dart';
import 'package:india_trading_app/models/stock_quote.dart';
import 'package:india_trading_app/pages/product_portfolio_page.dart';
import 'package:india_trading_app/l10n/app_language.dart';
import 'package:india_trading_app/theme/app_colors.dart';
import 'package:india_trading_app/theme/app_theme.dart';
import 'package:india_trading_app/utils/number_formatters.dart';
import 'package:india_trading_app/widgets/holding_detail_sheet.dart';
import 'package:india_trading_app/widgets/trading/holdings_tab.dart';

Map<String, dynamic> portfolioFixture({
  bool empty = false,
  bool history = true,
  String asOf = '2026-09-10T10:00:00Z',
}) {
  return {
    'asOf': asOf,
    'positionCount': empty ? 0 : 1,
    'currentValue': empty ? 0 : 120,
    'invested': empty ? 0 : 100,
    'totalPnl': empty ? 0 : 20,
    'realizedPnl': empty ? 0 : 5,
    'unrealizedPnl': empty ? 0 : 15,
    'bestSegment': empty ? null : 'Institutional',
    'history': {
      'points': !history || empty
          ? []
          : [
              {'productValue': 100},
              {'productValue': 120},
            ],
      'productProfitChange': empty || !history ? null : 20,
      'productFrom': asOf,
      'to': asOf,
    },
    'activity': empty
        ? []
        : [
            {
              'symbol': 'INSTCO',
              'category': 'Institutional',
              'status': 'FILLED',
              'quantity': 2,
              'filledQuantity': 2,
              'amount': 120,
              'at': asOf,
              'reference': 'ref-1',
              'type': 'ORDER',
            },
          ],
    'categories': [
      {
        'category': 'Institutional',
        'currentValue': empty ? 0 : 120,
        'invested': empty ? 0 : 100,
        'totalPnl': empty ? 0 : 20,
        'allocationPercent': empty ? 0 : 100,
        'positions': empty
            ? []
            : [
                {
                  'symbol': 'INSTCO',
                  'name': 'Institutional Company',
                  'exchange': 'NSE',
                  'quantity': 10,
                  'availableQuantity': 7,
                  'averagePrice': 10,
                  'currentPrice': 12,
                  'currentValue': 120,
                  'unrealizedPnl': 20,
                  'valuationSource': 'MARKET',
                },
              ],
      },
      {
        'category': 'OTC',
        'currentValue': 0,
        'invested': 0,
        'totalPnl': 0,
        'allocationPercent': 0,
        'positions': [],
      },
      {
        'category': 'IPO',
        'currentValue': 0,
        'invested': 0,
        'totalPnl': 0,
        'allocationPercent': 0,
        'positions': [],
      },
    ],
  };
}

Widget portfolioApp(
  Future<Map<String, dynamic>> Function(String) loader, {
  Size size = const Size(390, 844),
  double textScale = 1,
  bool reduceMotion = false,
}) {
  return MaterialApp(
    theme: AppTheme.light(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        size: size,
        textScaler: TextScaler.linear(textScale),
        disableAnimations: reduceMotion,
        accessibleNavigation: reduceMotion,
      ),
      child: child!,
    ),
    home: Scaffold(
      body: ProductPortfolioPage(
        loader: loader,
        onExplore: () {},
        onNotifications: () {},
      ),
    ),
  );
}

void setView(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> revealPortfolio(WidgetTester tester, Finder finder) async {
  await tester.dragUntilVisible(
    finder,
    find.byKey(const Key('portfolio-list')),
    const Offset(0, -280),
  );
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

PortfolioPosition equityHolding({
  int available = 7,
  String symbol = 'RELIANCE',
  String exchange = 'NSE',
}) {
  return PortfolioPosition(
    symbol: symbol,
    name: '$symbol Industries Limited Test Name',
    category: 'EQUITY',
    quantity: 12,
    availableQuantity: available,
    averageCost: 1400,
    realizedProfitLoss: 80,
    exchange: exchange,
  );
}

StockQuote liveQuote({bool fresh = true, double change = -1.2}) {
  return StockQuote(
    'RELIANCE',
    'Reliance Industries Limited Test Name',
    1456,
    change,
    1000,
    DateTime.utc(2026, 9, 10, 10),
    quoteFresh: fresh,
    previousClose: 1470,
  );
}

void main() {
  testWidgets('loading empty error and retry stay honest', (tester) async {
    setView(tester, const Size(390, 844));
    final gate = Completer<Map<String, dynamic>>();
    var calls = 0;
    await tester.pumpWidget(
      portfolioApp((_) {
        calls += 1;
        if (calls == 1) return gate.future;
        return Future.error(Exception('offline'));
      }),
    );
    expect(find.text('Loading portfolio'), findsOneWidget);
    expect(find.text('Total Portfolio Value'), findsNothing);
    gate.completeError(Exception('offline'));
    await tester.pumpAndSettle();
    expect(find.text('Unable to load portfolio'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.text('Total Portfolio Value'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty portfolio has no fake curve or allocation', (
    tester,
  ) async {
    setView(tester, const Size(390, 844));
    await tester.pumpWidget(
      portfolioApp((_) async => portfolioFixture(empty: true)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Total Portfolio Value'), findsOneWidget);
    expect(find.text('100%'), findsNothing);
    expect(find.text('Insufficient history'), findsNothing);
    expect(find.text('No investments yet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('populated portfolio formats assets and signed P&L', (
    tester,
  ) async {
    setView(tester, const Size(390, 844));
    await tester.pumpWidget(portfolioApp((_) async => portfolioFixture()));
    await tester.pumpAndSettle();
    expect(find.text(formatPrice(120)), findsWidgets);
    expect(find.text(formatPrice(100)), findsWidgets);
    expect(find.textContaining(formatSignedPrice(20)), findsWidgets);
    expect(find.textContaining('Gain'), findsWidgets);
    await revealPortfolio(
      tester,
      find.byKey(const ValueKey('product-holding-INSTCO')),
    );
    expect(find.textContaining('INSTCO · NSE'), findsOneWidget);
    expect(find.textContaining('Frozen 3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('asset details use high-contrast category icons', (tester) async {
    await tester.pumpWidget(portfolioApp((_) async => portfolioFixture()));
    await tester.pumpAndSettle();
    final icon = tester.widget<Icon>(
      find.byIcon(Icons.account_balance_outlined).first,
    );
    expect(icon.color, AppColors.textInverse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing history does not draw a fake curve', (tester) async {
    setView(tester, const Size(390, 844));
    await tester.pumpWidget(
      portfolioApp((_) async => portfolioFixture(history: false)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Insufficient history'), findsOneWidget);
    expect(find.byKey(const ValueKey('portfolio-history-chart')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('period chips do not reload the selected range', (tester) async {
    setView(tester, const Size(390, 844));
    final periods = <String>[];
    await tester.pumpWidget(
      portfolioApp((period) async {
        periods.add(period);
        return portfolioFixture();
      }),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('portfolio-period-1M')));
    await tester.pumpAndSettle();
    expect(periods, ['1M']);
    await tester.tap(find.byKey(const ValueKey('portfolio-period-1W')));
    await tester.pumpAndSettle();
    expect(periods, ['1M', '1W']);
  });

  testWidgets('negative P&L uses sign color and Loss text', (tester) async {
    setView(tester, const Size(390, 844));
    final data = portfolioFixture();
    data['totalPnl'] = -25;
    data['unrealizedPnl'] = -25;
    await tester.pumpWidget(portfolioApp((_) async => data));
    await tester.pumpAndSettle();
    expect(find.textContaining(formatSignedPrice(-25)), findsWidgets);
    expect(find.textContaining('Loss'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('portfolio hero keeps readable gains and losses on blue', (
    tester,
  ) async {
    setView(tester, const Size(390, 844));
    final gain = portfolioFixture();
    await tester.pumpWidget(portfolioApp((_) async => gain));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<AppText>(find.byKey(const ValueKey('portfolio-hero-returns')))
          .style
          ?.color,
      AppColors.chartGain,
    );
    final loss = portfolioFixture();
    loss['totalPnl'] = -20;
    loss['history'] = {
      'points': [
        {'productValue': 120},
        {'productValue': 100},
      ],
    };
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(portfolioApp((_) async => loss));
    await tester.pumpAndSettle();
    final lossColor = tester
        .widget<AppText>(find.byKey(const ValueKey('portfolio-hero-returns')))
        .style
        ?.color;
    expect(lossColor, const Color(0xFFFFB4B4));
    final chart = tester.widget<CustomPaint>(
      find.byKey(const ValueKey('portfolio-history-chart')),
    );
    expect((chart.painter as dynamic).color, lossColor);
  });

  testWidgets('holdings distinguish frozen available and delayed quotes', (
    tester,
  ) async {
    setView(tester, const Size(390, 844));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: HoldingsTab(
            positions: {'NSE:RELIANCE': equityHolding()},
            stocks: [liveQuote(fresh: false)],
            onSell: (_, {required isBuy}) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('RELIANCE'), findsOneWidget);
    expect(find.textContaining('Avail 7'), findsOneWidget);
    expect(find.textContaining('Frozen 5'), findsOneWidget);
    expect(find.text('Delayed quote'), findsOneWidget);
    expect(find.text('Unrealized P&L'), findsOneWidget);
    expect(find.textContaining('Gain'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('holding-filter-POSITIONS')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Frozen 5'), findsWidgets);
    expect(find.text('Open holding'), findsNothing);
    await tester.tap(find.text('RELIANCE'));
    await tester.pumpAndSettle();
    expect(find.text('Realized P&L'), findsOneWidget);
    expect(find.text('Unrealized P&L'), findsWidgets);
    expect(find.text('Frozen'), findsWidgets);
    expect(find.text('5'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing quote does not invent a current price', (tester) async {
    setView(tester, const Size(320, 568));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(1.3),
            disableAnimations: true,
          ),
          child: child!,
        ),
        home: Scaffold(
          body: HoldingsTab(
            positions: {
              'BSE:LONGSYMBOL': equityHolding(
                available: 12,
                symbol: 'LONGSYMBOL',
                exchange: 'BSE',
              ),
            },
            stocks: const [],
            onSell: (_, {required isBuy}) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Unavailable'), findsWidgets);
    expect(find.textContaining(formatPrice(1400)), findsWidgets);
    await tester.tap(find.text('LONGSYMBOL'));
    await tester.pumpAndSettle();
    expect(find.text('Current price'), findsOneWidget);
    expect(find.text('Unavailable'), findsWidgets);
    expect(find.text('Average cost'), findsOneWidget);
    expect(find.text(formatPrice(1400)), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('holding sell uses the existing D.1 callback', (tester) async {
    setView(tester, const Size(390, 844));
    final opened = <StockQuote>[];
    final sides = <bool>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: HoldingsTab(
            positions: {'NSE:RELIANCE': equityHolding()},
            stocks: [liveQuote()],
            onSell: (quote, {required bool isBuy}) {
              opened.add(quote);
              sides.add(isBuy);
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('RELIANCE'));
    await tester.pumpAndSettle();
    expect(opened, isEmpty);
    await tester.tap(find.text('Sell'));
    await tester.pumpAndSettle();
    expect(opened.single.symbol, 'RELIANCE');
    expect(sides, [false]);
  });

  testWidgets('reduced motion 320 portfolio has no overflow', (tester) async {
    setView(tester, const Size(320, 568));
    await tester.pumpWidget(
      portfolioApp(
        (_) async => portfolioFixture(),
        size: const Size(320, 568),
        textScale: 1.3,
        reduceMotion: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Total Portfolio Value'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty holdings and positions stay distinct', (tester) async {
    setView(tester, const Size(390, 844));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: HoldingsTab(
            positions: const {},
            stocks: const [],
            onSell: (_, {required isBuy}) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No holdings'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('holding-filter-POSITIONS')));
    await tester.pumpAndSettle();
    expect(find.text('No positions'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cost valuation keeps current price unavailable', (tester) async {
    setView(tester, const Size(390, 844));
    final data = portfolioFixture();
    final position =
        (((data['categories'] as List).first as Map)['positions'] as List).first
            as Map<String, dynamic>;
    position['valuationSource'] = 'COST';
    await tester.pumpWidget(portfolioApp((_) async => data));
    await tester.pumpAndSettle();
    await revealPortfolio(
      tester,
      find.byKey(const ValueKey('product-holding-INSTCO')),
    );
    await tester.tap(find.byKey(const ValueKey('product-holding-INSTCO')));
    await tester.pumpAndSettle();
    expect(find.text('Current price: Unavailable'), findsOneWidget);
    expect(find.text('Realized P&L: Unavailable'), findsOneWidget);
    expect(find.text("Day P&L: Unavailable"), findsOneWidget);
    expect(find.textContaining('Valued at cost'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('valuation time is shown in IST', (tester) async {
    setView(tester, const Size(390, 844));
    await tester.pumpWidget(portfolioApp((_) async => portfolioFixture()));
    await tester.pumpAndSettle();
    expect(find.textContaining('10/09/2026 15:30 IST'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  test('holding helpers keep frozen as remaining quantity', () {
    final position = equityHolding();
    expect(holdingFrozenQuantity(position), 5);
    expect(holdingQuoteUsable(null), isFalse);
    expect(holdingQuoteUsable(liveQuote()), isTrue);
  });
}
