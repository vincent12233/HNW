import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:india_trading_app/models/market_news_item.dart';
import 'package:india_trading_app/models/stock_quote.dart';
import 'package:india_trading_app/theme/app_motion.dart';
import 'package:india_trading_app/theme/app_spacing.dart';
import 'package:india_trading_app/theme/app_theme.dart';
import 'package:india_trading_app/utils/number_formatters.dart';
import 'package:india_trading_app/widgets/home/home_dashboard.dart';
import 'package:india_trading_app/widgets/home/home_action_button.dart';
import 'package:india_trading_app/widgets/home/home_dashboard_data.dart';

StockQuote quote({
  required String symbol,
  required String name,
  required double price,
  required double change,
  DateTime? updatedAt,
  bool quoteFresh = true,
}) {
  return StockQuote(
    symbol,
    name,
    price,
    change,
    1000,
    updatedAt ?? DateTime(2026, 9, 19, 10, 30),
    quoteFresh: quoteFresh,
    previousClose: price > 0 ? price / (1 + change / 100) : null,
  );
}

HomeDashboard dashboard({
  double totalAssets = 125000.5,
  double available = 82000.25,
  double frozen = 15000,
  double todayPnl = 2450.75,
  double? unrealizedPnl,
  bool accountLoaded = true,
  bool accountFailed = false,
  bool accountRefreshing = false,
  bool quotesLoading = false,
  bool? marketOpen = true,
  bool quotesConnected = true,
  bool hideBalances = false,
  bool kycAvailable = false,
  String kycStatus = 'UNKNOWN',
  List<HomeIndexQuote>? indices,
  List<StockQuote>? gainers,
  List<StockQuote>? losers,
  List<MarketNewsItem>? news,
  DateTime? quoteUpdatedAt,
  bool quotesStale = false,
  String? historyError,
  DateTime? historyUpdatedAt,
  List<double> portfolioSeries = const [],
  VoidCallback? onRetryAccount,
  VoidCallback? onRetryNews,
  VoidCallback? onRetryQuotes,
  VoidCallback? onDeposit,
  VoidCallback? onWithdraw,
  VoidCallback? onTrade,
  VoidCallback? onToggleHide,
  ValueChanged<MarketNewsItem>? onOpenNews,
}) {
  return HomeDashboard(
    accountName: 'Priya Sharmaji With A Very Long Client Name',
    totalAssets: totalAssets,
    availableFunds: available,
    frozenFunds: frozen,
    todayPnl: todayPnl,
    unrealizedPnl: unrealizedPnl,
    accountLoaded: accountLoaded,
    accountFailed: accountFailed,
    accountRefreshing: accountRefreshing,
    quotesLoading: quotesLoading,
    marketOpen: marketOpen,
    marketHours: '09:15 - 15:30 IST',
    quotesConnected: quotesConnected,
    indices:
        indices ??
        [
          const HomeIndexQuote(
            label: 'NIFTY 50',
            price: 24812.4,
            changePercent: 0.42,
            history: [24680, 24725, 24695, 24812.4],
          ),
          const HomeIndexQuote(
            label: 'SENSEX',
            price: 81200.1,
            changePercent: -0.18,
          ),
          const HomeIndexQuote(label: 'BANK NIFTY', price: 0, changePercent: 0),
          const HomeIndexQuote(
            label: 'INDIA VIX',
            price: 12.4,
            changePercent: 1.1,
          ),
        ],
    gainers:
        gainers ??
        [
          quote(
            symbol: 'RELIANCE',
            name: 'Reliance Industries Limited',
            price: 1456.3,
            change: 2.15,
          ),
        ],
    losers:
        losers ??
        [
          quote(
            symbol: 'TCS',
            name: 'Tata Consultancy Services',
            price: 3890.2,
            change: -1.44,
          ),
        ],
    news:
        news ??
        [
          MarketNewsItem(
            id: 'n1',
            title:
                'RBI keeps policy rate unchanged while reviewing liquidity conditions for the week',
            source: 'Exchange Desk',
            url: 'https://example.com/news',
            publishedAt: DateTime(2026, 9, 19, 9),
          ),
        ],
    hideBalances: hideBalances,
    kycAvailable: kycAvailable,
    kycStatus: kycStatus,
    quoteUpdatedAt: quoteUpdatedAt ?? DateTime(2026, 9, 19, 10, 28),
    quotesStale: quotesStale,
    historyError: historyError,
    historyUpdatedAt: historyUpdatedAt,
    portfolioSeries: portfolioSeries,
    onSearch: () {},
    onNotifications: () {},
    onToggleHideBalances: onToggleHide ?? () {},
    onDeposit: onDeposit ?? () {},
    onWithdraw: onWithdraw ?? () {},
    onTrade: onTrade ?? () {},
    onRetryAccount: onRetryAccount ?? () {},
    onRetryNews: onRetryNews ?? () {},
    onRetryQuotes: onRetryQuotes ?? () {},
    onOpenMarkets: () {},
    onOpenNews: onOpenNews ?? (_) {},
    onOpenStock: (_) {},
    onOpenKyc: () {},
    bottomPadding: AppSpacing.navHeight + AppSpacing.lg,
  );
}

Future<void> pumpHome(
  WidgetTester tester, {
  required Widget home,
  Size size = const Size(390, 844),
  double textScale = 1,
  bool reduceMotion = false,
  bool bottomNav = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: reduceMotion,
          accessibleNavigation: reduceMotion,
        ),
        child: child!,
      ),
      home: Scaffold(
        body: home,
        bottomNavigationBar: bottomNav
            ? NavigationBar(
                height: AppSpacing.navHeight,
                selectedIndex: 0,
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    label: 'Home',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.bar_chart_outlined),
                    label: 'Markets',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.swap_horiz_rounded),
                    label: 'Trade',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.pie_chart_outline),
                    label: 'Portfolio',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.person_outline),
                    label: 'Profile',
                  ),
                ],
              )
            : null,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void expectNoUnsupportedProductCtas() {
  expect(find.textContaining('F&O'), findsNothing);
  expect(find.textContaining('ETF'), findsNothing);
  expect(find.textContaining('Forex'), findsNothing);
  expect(find.textContaining('FX'), findsNothing);
  expect(find.textContaining('Currency'), findsNothing);
}

void main() {
  test('home movers and freshness use live quote fields only', () {
    final now = DateTime(2026, 9, 19, 11);
    final stocks = [
      quote(symbol: 'A', name: 'Alpha', price: 10, change: 4, updatedAt: now),
      quote(symbol: 'B', name: 'Beta', price: 20, change: -3, updatedAt: now),
      quote(symbol: 'C', name: 'Zero', price: 0, change: 9, updatedAt: now),
    ];
    expect(homeTopMovers(stocks, gainers: true).single.symbol, 'A');
    expect(homeTopMovers(stocks, gainers: false).single.symbol, 'B');
    expect(latestQuoteUpdatedAt(stocks), now);
    expect(
      homeQuoteFreshnessLabel(
        updatedAt: now.subtract(const Duration(minutes: 8)),
        quotesConnected: true,
        stale: true,
        now: now,
      ),
      contains('Quotes delayed'),
    );
    expect(homeKycTodo('APPROVED', available: true), HomeKycTodo.hidden);
    expect(homeKycTodo('PENDING', available: true), HomeKycTodo.pending);
    expect(homeKycTodo('UNKNOWN', available: false), HomeKycTodo.hidden);
  });

  testWidgets('stale portfolio history shows its last successful update', (
    tester,
  ) async {
    final updatedAt = DateTime(2026, 9, 26, 10, 30);
    await pumpHome(
      tester,
      home: dashboard(
        historyError: 'History unavailable. Try again later.',
        historyUpdatedAt: updatedAt,
        portfolioSeries: const [100, 105],
      ),
    );

    expect(find.text('History unavailable. Try again later.'), findsOneWidget);
    expect(
      find.text('Last updated ${formatIstDateTime(updatedAt)}'),
      findsOneWidget,
    );
  });

  testWidgets('loading hides amounts and does not claim a rally', (
    tester,
  ) async {
    await pumpHome(
      tester,
      home: dashboard(
        quotesLoading: true,
        accountLoaded: false,
        totalAssets: 999999,
        todayPnl: 8888,
      ),
    );
    expect(find.byType(LinearProgressIndicator), findsWidgets);
    expect(find.text(formatPrice(999999)), findsNothing);
    expect(find.text(formatSignedPrice(8888)), findsNothing);
    expect(find.textContaining('NSE & BSE Open'), findsOneWidget);
    expectNoUnsupportedProductCtas();
  });

  testWidgets('empty quotes and news do not invent sample values', (
    tester,
  ) async {
    await pumpHome(
      tester,
      home: dashboard(
        indices: const [
          HomeIndexQuote(label: 'NIFTY 50', price: 0, changePercent: 0),
        ],
        gainers: const [],
        losers: const [],
        news: const [],
        accountLoaded: true,
        totalAssets: 0,
        available: 0,
        frozen: 0,
        todayPnl: 0,
      ),
    );
    expect(find.text('Index quotes are unavailable.'), findsOneWidget);
    expect(find.text('No gainers right now'), findsOneWidget);
    expect(find.text('No losers right now'), findsOneWidget);
    expect(
      find.text('Live market news is temporarily unavailable.'),
      findsOneWidget,
    );
    expect(find.text(formatPrice(0)), findsWidgets);
    expect(find.textContaining('₹1,23,456'), findsNothing);
  });

  testWidgets('partial data keeps available indices and empty movers', (
    tester,
  ) async {
    await pumpHome(
      tester,
      home: dashboard(gainers: const [], losers: const [], news: const []),
    );
    expect(find.text(formatIndex(24812.4)), findsOneWidget);
    expect(find.text('Unavailable'), findsOneWidget);
    expect(find.text('No gainers right now'), findsOneWidget);
    expect(find.byTooltip('Retry news'), findsOneWidget);
  });

  testWidgets('account error retry does not fire until tapped', (tester) async {
    var accountRetries = 0;
    var quoteRetries = 0;
    await pumpHome(
      tester,
      reduceMotion: true,
      home: dashboard(
        accountLoaded: false,
        accountFailed: true,
        onRetryAccount: () => accountRetries++,
        onRetryQuotes: () => quoteRetries++,
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      find.text('Balances are unavailable. Please retry.'),
      findsOneWidget,
    );
    expect(find.text('--'), findsWidgets);
    expect(accountRetries, 0);
    expect(quoteRetries, 0);
    await tester.tap(find.text('Retry').first);
    expect(accountRetries, 1);
    expect(quoteRetries, 0);
  });

  testWidgets('market closed and stale quotes are explicit', (tester) async {
    await pumpHome(
      tester,
      home: dashboard(
        marketOpen: false,
        quotesConnected: false,
        quotesStale: true,
        quoteUpdatedAt: DateTime(2026, 9, 19, 9),
      ),
    );
    expect(find.text('NSE & BSE Closed'), findsOneWidget);
    expect(
      find.text('Live quotes reconnecting. Prices may be delayed.'),
      findsWidgets,
    );
    expect(find.text('NSE & BSE Open'), findsNothing);
  });

  testWidgets('formats assets, frozen funds and signed daily pnl', (
    tester,
  ) async {
    const assets = 125000.5;
    const available = 82000.25;
    const frozen = 15000.0;
    const pnl = -2450.75;
    await pumpHome(
      tester,
      home: dashboard(
        totalAssets: assets,
        available: available,
        frozen: frozen,
        todayPnl: pnl,
      ),
    );
    expect(find.text(formatPrice(assets)), findsOneWidget);
    expect(find.text(formatPrice(available)), findsOneWidget);
    expect(find.text(formatPrice(frozen)), findsOneWidget);
    expect(find.text(formatSignedPrice(pnl)), findsOneWidget);
    expect(find.text('Frozen Funds'), findsOneWidget);
    expect(find.text('Daily P&L'), findsOneWidget);
    expect(find.textContaining('+2.15%'), findsOneWidget);
    expect(find.textContaining('-1.44%'), findsOneWidget);
  });

  testWidgets('deposit stays on support assist and withdraw keeps callback', (
    tester,
  ) async {
    var deposits = 0;
    var withdrawals = 0;
    await pumpHome(
      tester,
      home: dashboard(
        onDeposit: () => deposits++,
        onWithdraw: () => withdrawals++,
      ),
    );
    expect(find.text('Instant Deposit'), findsOneWidget);
    expect(find.textContaining('payment gateway'), findsNothing);
    expect(find.textContaining('UPI'), findsNothing);
    await tester.ensureVisible(find.text('Add Money'));
    await tester.tap(find.text('Add Money'));
    await tester.ensureVisible(find.text('Withdraw'));
    await tester.tap(find.text('Withdraw'));
    expect(deposits, 1);
    expect(withdrawals, 1);
    expectNoUnsupportedProductCtas();
    expect(find.text('Open Trade'), findsOneWidget);
  });

  testWidgets('home actions fill two equal columns on phone and tablet', (
    tester,
  ) async {
    for (final width in [320.0, 390.0, 768.0]) {
      await pumpHome(tester, size: Size(width, 844), home: dashboard());
      final actions = find.byType(HomeActionButton);
      expect(actions, findsNWidgets(2));
      await tester.ensureVisible(actions.first);
      final first = tester.getRect(actions.first);
      final second = tester.getRect(actions.last);
      expect(first.width, closeTo(second.width, 0.1));
      expect(first.top, closeTo(second.top, 0.1));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('pending KYC todo appears only from real status', (tester) async {
    await pumpHome(tester, home: dashboard(kycAvailable: false));
    expect(find.text('KYC pending review'), findsNothing);
    await pumpHome(
      tester,
      home: dashboard(kycAvailable: true, kycStatus: 'PENDING'),
    );
    expect(find.text('KYC pending review'), findsOneWidget);
  });

  testWidgets('reduced motion still shows the full dashboard', (tester) async {
    await pumpHome(tester, reduceMotion: true, home: dashboard());
    expect(find.text('Total Portfolio Value'), findsOneWidget);
    expect(find.text('Market Indices'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('home-index-chart-NIFTY 50')),
      findsOneWidget,
    );
    expect(find.text('Market News'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('large text stacks news cards without clipping their actions', (
    tester,
  ) async {
    var opened = '';
    final articles = [
      for (var index = 0; index < 2; index++)
        MarketNewsItem(
          id: 'news-$index',
          title: 'Market update $index with a long headline about trading',
          source: 'Exchange Desk',
          url: 'https://example.com/$index',
          publishedAt: DateTime(2026, 9, 19),
        ),
    ];
    await pumpHome(
      tester,
      size: const Size(390, 844),
      textScale: 2,
      home: dashboard(news: articles, onOpenNews: (item) => opened = item.id),
    );
    await tester.ensureVisible(find.textContaining('Market update 0'));
    await tester.pump();
    final first = tester.getRect(find.textContaining('Market update 0'));
    final second = tester.getRect(find.textContaining('Market update 1'));
    expect(second.top, greaterThan(first.bottom));
    expect(tester.takeException(), isNull);
    await tester.tap(find.textContaining('Market update 0'));
    expect(opened, 'news-0');
  });

  testWidgets('phone market indices stay in one horizontal row', (
    tester,
  ) async {
    await pumpHome(tester, size: const Size(390, 844), home: dashboard());
    await tester.ensureVisible(find.text('Market Indices'));
    final nifty = tester.getRect(find.text('NIFTY 50').first);
    final sensex = tester.getRect(find.text('SENSEX').first);
    expect(nifty.top, closeTo(sensex.top, 4));
    expect(sensex.left, greaterThan(nifty.left));
    expect(tester.takeException(), isNull);
  });

  testWidgets('hide balances swaps amounts without extra requests', (
    tester,
  ) async {
    var retries = 0;
    var hidden = false;
    await pumpHome(
      tester,
      home: dashboard(
        hideBalances: hidden,
        onRetryAccount: () => retries++,
        onToggleHide: () => hidden = true,
      ),
    );
    expect(find.text(formatPrice(125000.5)), findsOneWidget);
    await tester.tap(find.byTooltip('Hide balances'));
    expect(retries, 0);
  });

  testWidgets('320 and 390 layouts do not overflow at 1.3 text scale', (
    tester,
  ) async {
    for (final size in [const Size(320, 568), const Size(390, 844)]) {
      await pumpHome(
        tester,
        size: size,
        textScale: 1.3,
        bottomNav: true,
        home: dashboard(
          totalAssets: 12345678.9,
          available: 9876543.21,
          frozen: 1000000,
          todayPnl: -876543.21,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull, reason: '$size overflowed');
      expect(find.byType(NavigationBar), findsOneWidget);
      await tester.ensureVisible(find.text('Open Trade'));
      await tester.pump();
      final tradeBottom = tester.getBottomLeft(find.text('Open Trade')).dy;
      final navTop = tester.getTopLeft(find.byType(NavigationBar)).dy;
      expect(tradeBottom, lessThanOrEqualTo(navTop + 1));
    }
  });

  testWidgets('fade switch respects AppMotion and does not refetch', (
    tester,
  ) async {
    var retries = 0;
    await pumpHome(tester, home: dashboard(onRetryAccount: () => retries++));
    expect(find.byType(AppFadeIn), findsOneWidget);
    await tester.pump(AppMotion.page);
    expect(retries, 0);
  });

  testWidgets('zero total assets and unrealized P&L stay visible as zero', (
    tester,
  ) async {
    await pumpHome(
      tester,
      home: dashboard(
        totalAssets: 0,
        unrealizedPnl: 0,
        available: 0,
        frozen: 0,
        todayPnl: 0,
      ),
    );
    expect(find.text(formatPrice(0)), findsWidgets);
    expect(find.text(formatSignedPrice(0)), findsWidgets);
    expect(find.text('Unrealized P&L'), findsOneWidget);
    expect(find.textContaining('******'), findsNothing);
  });

  testWidgets('hidden balances do not leak authoritative amounts', (
    tester,
  ) async {
    await pumpHome(
      tester,
      home: dashboard(
        hideBalances: true,
        totalAssets: 888888,
        unrealizedPnl: -12.5,
        todayPnl: 9,
      ),
    );
    expect(find.text(formatPrice(888888)), findsNothing);
    expect(find.text(formatSignedPrice(-12.5)), findsNothing);
    expect(find.text(formatSignedPrice(9)), findsNothing);
    expect(find.text('******'), findsWidgets);
  });

  testWidgets('320 text scale 1.5 with unrealized metric does not overflow', (
    tester,
  ) async {
    await pumpHome(
      tester,
      size: const Size(320, 568),
      textScale: 1.5,
      reduceMotion: true,
      home: dashboard(totalAssets: 0, unrealizedPnl: 0, todayPnl: -1),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Unrealized P&L'), findsOneWidget);
  });
}
