import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:india_trading_app/pages/stock_search_page.dart';
import 'package:india_trading_app/services/market_data_service.dart';
import 'package:india_trading_app/services/watchlist_service.dart';

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

class EmptyWatchlist extends WatchlistService {
  @override
  Future<Set<String>> fetchSymbols() async => {};
}

MarketSearchPage emptyPage(int page, {bool hasMore = false}) =>
    MarketSearchPage(
      data: const [],
      total: hasMore ? 400 : 0,
      page: page,
      pageSize: 100,
      hasMore: hasMore,
    );

Widget searchApp(SearchFake service) => MaterialApp(
  home: StockSearchPage(
    initialStocks: const [],
    onSelected: (_) {},
    marketDataService: service,
    watchlistService: EmptyWatchlist(),
  ),
);

void main() {
  testWidgets('keyboard search runs immediately without a second debounce', (
    tester,
  ) async {
    final service = SearchFake((_, page) async => emptyPage(page));
    await tester.pumpWidget(searchApp(service));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '  TCS  ');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(service.requests.where((request) => request.$1 == 'TCS'), [
      ('TCS', 1),
    ]);
    expect(find.text('No matching stocks'), findsOneWidget);
    expect(tester.testTextInput.isVisible, isFalse);
    await tester.pump(const Duration(milliseconds: 400));
    expect(service.requests.where((request) => request.$1 == 'TCS').length, 1);
  });

  testWidgets('an older failed query cannot replace the current result', (
    tester,
  ) async {
    final oldRequest = Completer<MarketSearchPage>();
    final service = SearchFake(
      (query, page) =>
          query == 'OLD' ? oldRequest.future : Future.value(emptyPage(page)),
    );
    await tester.pumpWidget(searchApp(service));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'OLD');
    await tester.pump(const Duration(milliseconds: 310));
    await tester.enterText(find.byType(TextField), 'NEW');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    oldRequest.completeError(Exception('Old request is offline'));
    await tester.pumpAndSettle();

    expect(find.text('No matching stocks'), findsOneWidget);
    expect(find.text('Unable to load stocks'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pagination retry requests the failed page without restarting', (
    tester,
  ) async {
    var failed = false;
    final service = SearchFake((_, page) async {
      if (page < 4) return emptyPage(page, hasMore: true);
      if (!failed) {
        failed = true;
        throw Exception('Page 4 temporarily unavailable');
      }
      return emptyPage(page);
    });
    await tester.pumpWidget(searchApp(service));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Load more'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(service.requests.map((request) => request.$2), [1, 2, 3, 4, 4]);
    expect(find.text('No instruments available'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('search controls remain usable on a narrow phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = SearchFake((_, page) async => emptyPage(page));
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(1.4),
            viewInsets: const EdgeInsets.only(bottom: 220),
          ),
          child: child!,
        ),
        home: StockSearchPage(
          initialStocks: const [],
          onSelected: (_) {},
          marketDataService: service,
          watchlistService: EmptyWatchlist(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'ABC');
    await tester.pumpAndSettle();
    expect(find.byTooltip('Clear'), findsOneWidget);
    expect(
      tester.getRect(find.byTooltip('Clear')).right,
      lessThanOrEqualTo(320),
    );
    expect(tester.takeException(), isNull);
  });
}
