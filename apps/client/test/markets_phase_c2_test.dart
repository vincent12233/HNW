import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:india_trading_app/models/stock_quote.dart';
import 'package:india_trading_app/models/trading_order.dart';
import 'package:india_trading_app/pages/stock_search_page.dart';
import 'package:india_trading_app/services/market_data_service.dart';
import 'package:india_trading_app/services/watchlist_service.dart';
import 'package:india_trading_app/theme/app_motion.dart';
import 'package:india_trading_app/theme/app_theme.dart';
import 'package:india_trading_app/utils/number_formatters.dart';
import 'package:india_trading_app/widgets/market_status_card.dart';
import 'package:india_trading_app/widgets/markets/browse_only_banner.dart';
import 'package:india_trading_app/widgets/markets/instrument_browse.dart';
import 'package:india_trading_app/widgets/markets/markets_index_card.dart';
import 'package:india_trading_app/widgets/markets/stock_quote_hero.dart';
import 'package:india_trading_app/widgets/stock_list_tile.dart';

StockQuote quote({
  required String symbol,
  required String name,
  required double price,
  required double change,
  String? category,
  String? logoUrl,
  bool quoteFresh = true,
  DateTime? updatedAt,
  int volume = 12000,
}) {
  return StockQuote(
    symbol,
    name,
    price,
    change,
    volume,
    updatedAt ?? DateTime(2026, 9, 19, 10, 30),
    category: category,
    logoUrl: logoUrl,
    quoteFresh: quoteFresh,
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
    home: Scaffold(body: child),
  );
}

void setView(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

class SearchFake extends MarketDataService {
  SearchFake(this.respond);
  final Future<MarketSearchPage> Function(String query, int page) respond;
  final requests = <(String, int)>[];

  @override
  Future<MarketSearchPage> searchSnapshot({
    String query = '',
    int page = 1,
    int pageSize = 50,
  }) {
    requests.add((query, page));
    return respond(query, page);
  }
}

class CountingWatchlist extends WatchlistService {
  CountingWatchlist({
    Set<String> symbols = const <String>{},
    this.failLoad = false,
  }) : symbols = Set.of(symbols);

  Set<String> symbols;
  bool failLoad;
  int fetches = 0;
  int adds = 0;
  int removes = 0;
  Completer<void>? gate;

  @override
  Future<Set<String>> fetchSymbols() async {
    fetches++;
    if (failLoad) throw const WatchlistException('Please sign in again');
    return Set.of(symbols);
  }

  @override
  Future<void> add(String symbol, {String exchange = 'NSE'}) async {
    adds++;
    await (gate?.future ?? Future<void>.value());
    symbols.add(WatchlistService.key(exchange, symbol));
  }

  @override
  Future<void> remove(String symbol, {String exchange = 'NSE'}) async {
    removes++;
    await (gate?.future ?? Future<void>.value());
    symbols.remove(WatchlistService.key(exchange, symbol));
  }
}

MarketSearchPage pageOf(List<StockQuote> data, {int page = 1}) =>
    MarketSearchPage(
      data: data,
      total: data.length,
      page: page,
      pageSize: 100,
      hasMore: false,
    );

void main() {
  test('browse-only instruments exclude equity from trade gating', () {
    expect(
      isBrowseOnlyInstrument(
        quote(symbol: 'TCS', name: 'TCS', price: 1, change: 1),
      ),
      isFalse,
    );
    expect(
      isBrowseOnlyInstrument(
        quote(
          symbol: 'NIFTY25SEP',
          name: 'Nifty Future',
          price: 1,
          change: 1,
          category: 'F&O',
        ),
      ),
      isTrue,
    );
    expect(
      isBrowseOnlyInstrument(
        quote(symbol: 'NIFTYBEES', name: 'Nifty ETF', price: 1, change: 1),
      ),
      isTrue,
    );
    expect(
      isBrowseOnlyInstrument(
        quote(
          symbol: 'USDINR',
          name: 'USDINR',
          price: 1,
          change: 1,
          category: 'CURRENCY',
        ),
      ),
      isTrue,
    );
    expect(
      isBrowseOnlyInstrument(
        quote(
          symbol: 'GOLD',
          name: 'Gold',
          price: 1,
          change: 1,
          category: 'COMMODITY',
        ),
      ),
      isTrue,
    );
  });

  test('equity order payload keeps MARKET/LIMIT and DAY/IOC/FOK fields', () {
    final order = TradingOrder(
      symbol: 'TCS',
      exchange: 'NSE',
      isBuy: true,
      quantity: 2,
      price: 3500.25,
      placedAt: DateTime.utc(2026, 9, 19, 4, 30),
      type: 'LIMIT',
      timeInForce: 'IOC',
      limitPrice: 3499.5,
    );
    expect(order.symbol, 'TCS');
    expect(order.exchange, 'NSE');
    expect(order.type, 'LIMIT');
    expect(order.timeInForce, 'IOC');
    expect(order.isBuy, isTrue);
    expect(order.limitPrice, 3499.5);
  });

  testWidgets('index cards format Yahoo-only quotes and hide missing prices', (
    tester,
  ) async {
    setView(tester, const Size(390, 844));
    await tester.pumpWidget(
      host(
        SingleChildScrollView(
          child: Column(
            children: const [
              MarketsIndexCard(
                label: 'NIFTY 50',
                price: 24812.4,
                changePercent: 0.42,
              ),
              MarketsIndexCard(
                label: 'SENSEX',
                price: 0,
                changePercent: 0,
                venue: 'BSE',
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.text(formatIndex(24812.4)), findsOneWidget);
    expect(find.text('+0.42%'), findsOneWidget);
    expect(find.text('Awaiting live quote'), findsOneWidget);
    expect(find.textContaining('₹24,812'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('gainers and losers show color, sign and delayed quote', (
    tester,
  ) async {
    setView(tester, const Size(320, 568));
    await tester.pumpWidget(
      host(
        Column(
          children: [
            StockListTile(
              stock: quote(
                symbol: 'TCS',
                name: 'Tata Consultancy Services Limited Extra Long Name',
                price: 3500.25,
                change: 1.25,
              ),
              onTap: () {},
            ),
            StockListTile(
              stock: quote(
                symbol: 'INFY',
                name: 'Infosys',
                price: 1480.5,
                change: -2.1,
                quoteFresh: false,
              ),
              onTap: () {},
            ),
          ],
        ),
        size: const Size(320, 568),
        textScale: 1.3,
      ),
    );
    expect(find.text(formatPrice(3500.25)), findsOneWidget);
    expect(find.textContaining('+'), findsWidgets);
    expect(find.text(formatPrice(1480.5)), findsOneWidget);
    expect(find.byTooltip('Delayed quote'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stock hero marks delayed quotes and uses real model fields', (
    tester,
  ) async {
    setView(tester, const Size(390, 844));
    final stock = quote(
      symbol: 'RELIANCE',
      name: 'Reliance Industries',
      price: 1402.35,
      change: -0.84,
      quoteFresh: false,
      updatedAt: DateTime.now().subtract(const Duration(minutes: 8)),
    );
    await tester.pumpWidget(
      host(StockQuoteHero(stock: stock, quotesConnected: true)),
    );
    expect(find.text('RELIANCE · NSE'), findsOneWidget);
    expect(find.text(formatPrice(1402.35)), findsOneWidget);
    expect(find.text('DELAYED'), findsOneWidget);
    expect(find.textContaining('Buy'), findsNothing);
    expect(find.textContaining('Sell'), findsNothing);
  });

  testWidgets(
    'unsupported products render browse-only copy without trade CTA',
    (tester) async {
      setView(tester, const Size(390, 844));
      final future = quote(
        symbol: 'BANKNIFTY25SEP',
        name: 'Bank Nifty Future',
        price: 51200,
        change: 0.4,
        category: 'F&O',
      );
      await tester.pumpWidget(
        host(
          Column(
            children: [
              StockQuoteHero(stock: future, quotesConnected: true),
              if (isBrowseOnlyInstrument(future))
                const BrowseOnlyBanner(productLabel: 'F&O'),
            ],
          ),
        ),
      );
      expect(find.text('F&O is browse only'), findsOneWidget);
      expect(find.text('BUY'), findsNothing);
      expect(find.text('SELL'), findsNothing);
      expect(find.text('Place Order'), findsNothing);
    },
  );

  testWidgets('market closed uses the real session card', (tester) async {
    await tester.pumpWidget(
      host(const MarketStatusCard(isOpen: false, hours: '09:15 - 15:30 IST')),
    );
    expect(find.text('NSE Closed'), findsOneWidget);
    expect(find.text('09:15 - 15:30 IST'), findsOneWidget);
  });

  testWidgets('search empty, error retry, and no duplicate in-flight add', (
    tester,
  ) async {
    setView(tester, const Size(390, 844));
    var failOnce = true;
    final watchlist = CountingWatchlist();
    watchlist.gate = Completer<void>();
    final service = SearchFake((query, page) async {
      if (failOnce) {
        failOnce = false;
        throw Exception('offline');
      }
      return pageOf(const []);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: StockSearchPage(
          initialStocks: const [],
          onSelected: (_) {},
          marketDataService: service,
          watchlistService: watchlist,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Unable to load stocks'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(service.requests.where((request) => request.$1 == '').length, 2);
    expect(find.text('No instruments available'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'ZZZ');
    await tester.pump(const Duration(milliseconds: 310));
    await tester.pumpAndSettle();
    expect(find.text('No matching stocks'), findsOneWidget);

    var favorite = false;
    final saving = <String>{};
    Future<void> toggle() async {
      const key = 'NSE:HDFCBANK';
      if (saving.contains(key)) return;
      saving.add(key);
      if (favorite) {
        await watchlist.remove('HDFCBANK');
        favorite = false;
      } else {
        await watchlist.add('HDFCBANK');
        favorite = true;
      }
      saving.remove(key);
    }

    await tester.pumpWidget(
      host(
        IconButton(
          tooltip: favorite ? 'Remove from watchlist' : 'Add to watchlist',
          onPressed: toggle,
          icon: Icon(favorite ? Icons.star : Icons.star_border),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Add to watchlist'));
    await tester.pump();
    await tester.tap(find.byTooltip('Add to watchlist'));
    expect(watchlist.adds, 1);
    watchlist.gate!.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('watchlist permission error keeps the server message', (
    tester,
  ) async {
    final watchlist = CountingWatchlist(failLoad: true);
    final service = SearchFake((_, page) async => pageOf(const []));
    await tester.pumpWidget(
      MaterialApp(
        home: StockSearchPage(
          initialStocks: const [],
          onSelected: (_) {},
          marketDataService: service,
          watchlistService: watchlist,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Unable to load watchlist'), findsOneWidget);
  });

  testWidgets('reduced motion keeps markets chrome without overflow at 320', (
    tester,
  ) async {
    setView(tester, const Size(320, 568));
    await tester.pumpWidget(
      host(
        AppFadeIn(
          switchKey: 'markets',
          child: Column(
            children: [
              const MarketStatusCard(isOpen: true),
              MarketsIndexCard(
                label: 'NIFTY 50',
                price: 24812.4,
                changePercent: -0.12,
              ),
              StockListTile(
                stock: quote(
                  symbol: 'VERYLONGSYMBOLNAME',
                  name: 'A Company Name That Must Ellipsize On Small Phones',
                  price: 1234567.89,
                  change: 12.34,
                ),
                onTap: () {},
                onFavorite: () {},
                isFavorite: true,
              ),
            ],
          ),
        ),
        size: const Size(320, 568),
        textScale: 1.3,
        reduceMotion: true,
      ),
    );
    expect(AppMotion.reduce(tester.element(find.byType(AppFadeIn))), isTrue);
    expect(tester.takeException(), isNull);
    expect(find.text(formatPrice(1234567.89)), findsOneWidget);
  });
}
