import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:india_trading_app/models/market_news_item.dart';
import 'package:india_trading_app/models/stock_quote.dart';
import 'package:india_trading_app/pages/index_detail_page.dart';
import 'package:india_trading_app/pages/index_list_page.dart';
import 'package:india_trading_app/pages/market_news_page.dart';
import 'package:india_trading_app/pages/movers_list_page.dart';
import 'package:india_trading_app/pages/stock_detail_page.dart';
import 'package:india_trading_app/theme/app_motion.dart';
import 'package:india_trading_app/theme/app_theme.dart';
import 'package:india_trading_app/widgets/home/home_dashboard.dart';
import 'package:india_trading_app/widgets/home/home_dashboard_data.dart';
import 'package:india_trading_app/widgets/markets/browse_only_banner.dart';
import 'package:india_trading_app/widgets/markets/instrument_news.dart';
import 'package:india_trading_app/widgets/markets/market_index_ref.dart';
import 'package:india_trading_app/widgets/stock_history_chart.dart';

StockQuote quote({
  required String symbol,
  required String name,
  required double price,
  required double change,
  String? category,
  int volume = 12000,
}) {
  return StockQuote(
    symbol,
    name,
    price,
    change,
    volume,
    DateTime(2026, 9, 19, 10, 30),
    category: category,
    previousClose: price > 0 ? price / (1 + change / 100) : null,
  );
}

Widget host(
  Widget child, {
  Size size = const Size(390, 844),
  double textScale = 1,
  bool reduceMotion = false,
}) {
  return MaterialApp(
    theme: AppTheme.light(),
    builder: (context, content) {
      final media = MediaQuery.of(context);
      return MediaQuery(
        data: media.copyWith(
          size: size,
          textScaler: TextScaler.linear(textScale),
          disableAnimations: reduceMotion,
          accessibleNavigation: reduceMotion,
        ),
        child: content!,
      );
    },
    home: child,
  );
}

void setView(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> pumpFrames(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> disposeTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

MarketNewsItem article({
  required String title,
  String source = 'Exchange',
  String url = 'https://example.com/a',
}) {
  return MarketNewsItem(
    id: title,
    title: title,
    source: source,
    url: url,
    publishedAt: DateTime(2026, 9, 19),
  );
}

HomeDashboard home({ValueChanged<HomeIndexQuote>? onOpenIndex}) {
  return HomeDashboard(
    accountName: 'Priya',
    totalAssets: 100000,
    availableFunds: 20000,
    frozenFunds: 1000,
    todayPnl: 120,
    accountLoaded: true,
    accountFailed: false,
    accountRefreshing: false,
    quotesLoading: false,
    marketOpen: true,
    marketHours: '09:15 - 15:30 IST',
    quotesConnected: true,
    indices: const [
      HomeIndexQuote(
        label: 'NIFTY 50',
        price: 24812.4,
        changePercent: 0.42,
        history: [24740, 24785, 24812.4],
      ),
      HomeIndexQuote(label: 'SENSEX', price: 81200.1, changePercent: -0.18),
    ],
    gainers: [
      quote(symbol: 'RELIANCE', name: 'Reliance', price: 1456, change: 2.1),
    ],
    losers: [quote(symbol: 'INFY', name: 'Infosys', price: 1490, change: -1.2)],
    news: [article(title: 'Markets open higher')],
    onSearch: () {},
    onNotifications: () {},
    onToggleHideBalances: () {},
    onDeposit: () {},
    onWithdraw: () {},
    onTrade: () {},
    onRetryAccount: () {},
    onRetryNews: () {},
    onRetryQuotes: () {},
    onOpenMarkets: () {},
    onOpenNews: (_) {},
    onOpenStock: (_) {},
    onOpenIndex: onOpenIndex,
  );
}

void main() {
  test('history charts stay limited to NSE and BSE index refs', () {
    expect(MarketIndexRef.byLabel('NIFTY 50')!.supportsHistoryChart, isTrue);
    expect(MarketIndexRef.byLabel('SENSEX')!.supportsHistoryChart, isTrue);
    expect(MarketIndexRef.byLabel('DOW JONES')!.supportsHistoryChart, isFalse);
    expect(MarketIndexRef.byLabel('NASDAQ')!.supportsHistoryChart, isFalse);
  });

  test('related news only keeps verified headlines that mention the stock', () {
    final stock = quote(
      symbol: 'RELIANCE',
      name: 'Reliance Industries Limited',
      price: 1400,
      change: 1,
    );
    final items = [
      article(title: 'RELIANCE posts quarterly update'),
      article(title: 'Infosys guidance unchanged'),
      article(title: 'Broad market wrap', source: 'Reliance Desk'),
    ];
    final related = newsMentioningInstrument(items, stock);
    expect(related.map((item) => item.title), [
      'RELIANCE posts quarterly update',
      'Broad market wrap',
    ]);
  });

  testWidgets(
    'index list empty state is honest and tappable rows open detail',
    (tester) async {
      setView(tester, const Size(390, 844));
      await tester.pumpWidget(
        host(const IndexListPage(title: 'Indian Indices', items: [])),
      );
      await pumpFrames(tester);
      expect(find.text('Index quotes unavailable'), findsOneWidget);
      expect(find.textContaining('Buy'), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        host(
          IndexListPage(
            title: 'Global Indices',
            items: [
              MarketIndexQuote(
                ref: MarketIndexRef.byLabel('DOW JONES')!,
                price: 41000,
                changePercent: 0.15,
              ),
            ],
          ),
        ),
      );
      await pumpFrames(tester);
      await tester.tap(find.text('DOW JONES'));
      await pumpFrames(tester);
      expect(find.text('Index is browse only'), findsOneWidget);
      expect(
        find.text('Indices cannot be bought or sold in this app.'),
        findsOneWidget,
      );
      expect(find.text('Full history is unavailable'), findsOneWidget);
      expect(find.byType(StockHistoryChart), findsNothing);
      expect(find.text('BUY'), findsNothing);
      expect(find.text('SELL'), findsNothing);
    },
  );

  testWidgets('global index detail uses honest history empty state', (
    tester,
  ) async {
    setView(tester, const Size(320, 568));
    await tester.pumpWidget(
      host(
        IndexDetailPage(
          quote: MarketIndexQuote(
            ref: MarketIndexRef.byLabel('DOW JONES')!,
            price: 41000,
            changePercent: 0.2,
          ),
          marketOpen: false,
        ),
        size: const Size(320, 568),
        textScale: 1.3,
        reduceMotion: true,
      ),
    );
    await pumpFrames(tester);
    expect(find.text('Full history is unavailable'), findsOneWidget);
    expect(find.byType(StockHistoryChart), findsNothing);
    expect(find.text('BUY'), findsNothing);
    expect(find.text('Open Trade'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('movers list filters, empty state, and stock navigation', (
    tester,
  ) async {
    setView(tester, const Size(390, 844));
    StockQuote? opened;
    final gainer = quote(
      symbol: 'RELIANCE',
      name: 'Reliance Industries',
      price: 1456,
      change: 2.1,
    );
    await tester.pumpWidget(
      host(
        MoversListPage(
          gainers: [gainer],
          losers: const [],
          mostActive: const [],
          yearHigh: const [],
          yearLow: const [],
          onStockTap: (stock) => opened = stock,
          marketOpen: true,
        ),
      ),
    );
    await pumpFrames(tester);
    expect(
      find.text('No instruments match this market filter.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Top Gainers'));
    await pumpFrames(tester);
    expect(find.text('RELIANCE'), findsOneWidget);
    await tester.tap(find.text('RELIANCE'));
    expect(opened?.symbol, 'RELIANCE');
    await tester.tap(find.text('52 Week High'));
    await pumpFrames(tester);
    expect(
      find.text('No instruments match this market filter.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('news list opens an honest sheet before the external link', (
    tester,
  ) async {
    setView(tester, const Size(390, 844));
    var opened = 0;
    await tester.pumpWidget(
      host(
        MarketNewsPage(
          items: [article(title: 'RBI keeps rates unchanged')],
          onOpen: (_) async => opened += 1,
        ),
      ),
    );
    await pumpFrames(tester);
    await tester.tap(find.text('RBI keeps rates unchanged'));
    await pumpFrames(tester);
    expect(
      find.textContaining('HNW does not host a full in-app news body'),
      findsOneWidget,
    );
    expect(opened, 0);
    await tester.tap(find.text('Open article'));
    await pumpFrames(tester);
    expect(opened, 1);
  });

  testWidgets('stock detail keeps trade callbacks and hides them for F&O', (
    tester,
  ) async {
    setView(tester, const Size(390, 844));
    var orders = 0;
    await tester.pumpWidget(
      host(
        StockDetailPage(
          stock: quote(
            symbol: 'RELIANCE',
            name: 'Reliance Industries',
            price: 1456,
            change: 1.2,
          ),
          onOrderPlaced: (_) async {
            orders += 1;
            return null;
          },
        ),
      ),
    );
    await pumpFrames(tester);
    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('Chart'), findsOneWidget);
    expect(find.text('News'), findsOneWidget);
    expect(find.text('Events'), findsOneWidget);
    expect(find.text('BUY'), findsOneWidget);
    expect(find.text('Place Order'), findsOneWidget);
    expect(find.text('News'), findsOneWidget);
    expect(find.text('Events'), findsOneWidget);
    expect(orders, 0);
    await disposeTree(tester);
  });

  testWidgets('F&O stock detail has no trade CTA', (tester) async {
    setView(tester, const Size(390, 844));
    var orders = 0;
    await tester.pumpWidget(
      host(
        StockDetailPage(
          stock: quote(
            symbol: 'NIFTYFUT',
            name: 'Nifty Future',
            price: 24800,
            change: 0.4,
            category: 'F&O',
          ),
          onOrderPlaced: (_) async {
            orders += 1;
            return null;
          },
        ),
      ),
    );
    await pumpFrames(tester);
    expect(find.byType(BrowseOnlyBanner), findsOneWidget);
    expect(find.text('BUY'), findsNothing);
    expect(find.text('SELL'), findsNothing);
    expect(find.text('Place Order'), findsNothing);
    expect(orders, 0);
    await disposeTree(tester);
  });

  testWidgets('home index chips open the same index detail route', (
    tester,
  ) async {
    setView(tester, const Size(390, 844));
    HomeIndexQuote? opened;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: home(onOpenIndex: (item) => opened = item)),
      ),
    );
    await pumpFrames(tester);
    await tester.ensureVisible(find.text('NIFTY 50'));
    await tester.tap(find.text('NIFTY 50'));
    expect(opened?.label, 'NIFTY 50');
    expect(opened?.history, [24740, 24785, 24812.4]);
  });

  testWidgets(
    'secondary pages fit small, tablet and desktop without overflow',
    (tester) async {
      const sizes = [
        Size(320, 568),
        Size(390, 844),
        Size(768, 1024),
        Size(1440, 900),
      ];
      for (final size in sizes) {
        setView(tester, size);
        await tester.pumpWidget(
          host(
            IndexListPage(
              title: 'Global Indices',
              items: [
                MarketIndexQuote(
                  ref: MarketIndexRef.byLabel('DOW JONES')!,
                  price: 41000,
                  changePercent: 0.15,
                ),
              ],
              marketOpen: false,
            ),
            size: size,
            textScale: 1.3,
            reduceMotion: true,
          ),
        );
        await pumpFrames(tester);
        expect(tester.takeException(), isNull, reason: 'index list $size');

        await tester.pumpWidget(
          host(
            MoversListPage(
              gainers: const [],
              losers: const [],
              mostActive: const [],
              yearHigh: const [],
              yearLow: const [],
              onStockTap: (_) {},
              yearRangesLoading: true,
              initialFilter: 3,
            ),
            size: size,
            textScale: 1.3,
            reduceMotion: true,
          ),
        );
        await pumpFrames(tester);
        expect(
          find.textContaining('Loading one-year market history'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull, reason: 'movers $size');

        await tester.pumpWidget(
          host(
            MarketNewsPage(items: const [], onOpen: (_) async {}),
            size: size,
            textScale: 1.3,
            reduceMotion: true,
          ),
        );
        await pumpFrames(tester);
        expect(tester.takeException(), isNull, reason: 'news $size');
      }
    },
  );

  testWidgets('reduced motion keeps index detail readable', (tester) async {
    setView(tester, const Size(390, 844));
    await tester.pumpWidget(
      host(
        IndexDetailPage(
          quote: MarketIndexQuote(
            ref: MarketIndexRef.byLabel('DOW JONES')!,
            price: 41000,
            changePercent: 0.2,
          ),
          marketOpen: true,
        ),
        reduceMotion: true,
      ),
    );
    await tester.pump();
    expect(find.byType(AppFadeIn), findsWidgets);
    await tester.pump(AppMotion.page);
    expect(find.text('Index is browse only'), findsOneWidget);
    expect(find.byType(StockHistoryChart), findsNothing);
  });
}
