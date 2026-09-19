import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:india_trading_app/models/account_transaction.dart';
import 'package:india_trading_app/models/stock_quote.dart';
import 'package:india_trading_app/models/trading_order.dart';
import 'package:india_trading_app/pages/stock_detail_page.dart';
import 'package:india_trading_app/pages/trading_center_page.dart';
import 'package:india_trading_app/services/trading_service.dart';
import 'package:india_trading_app/theme/app_theme.dart';
import 'package:india_trading_app/utils/number_formatters.dart';
import 'package:india_trading_app/widgets/markets/browse_only_banner.dart';
import 'package:shared_preferences/shared_preferences.dart';

StockQuote equity({
  String symbol = 'RELIANCE',
  String name = 'Reliance Industries Limited Test Name',
  String? category,
}) {
  return StockQuote(
    symbol,
    name,
    1456,
    1.2,
    12000,
    DateTime.now(),
    category: category,
    ask: 1456.5,
    bid: 1455.5,
    quoteFresh: true,
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

Future<void> reveal(
  WidgetTester tester,
  Finder finder, {
  Key scrollKey = const Key('stock-overview'),
}) async {
  await tester.scrollUntilVisible(
    finder,
    240,
    scrollable: find.descendant(
      of: find.byKey(scrollKey),
      matching: find.byWidgetPredicate(
        (widget) => widget is Scrollable && widget.axis == Axis.vertical,
      ),
    ),
  );
  await tester.pump();
}

Finder confirmButton() => find.byKey(const Key('order-confirm'));

Future<void> openConfirm(WidgetTester tester, {bool buy = true}) async {
  await tester.tap(find.widgetWithText(FilledButton, buy ? 'BUY' : 'SELL'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 400));
}

Map<String, dynamic> apiPayload(TradingOrder order) {
  final body = <String, dynamic>{
    'clientOrderId': order.clientOrderId,
    'exchange': order.exchange,
    'symbol': order.symbol,
    'side': order.isBuy ? 'BUY' : 'SELL',
    'type': order.type,
    'timeInForce': order.timeInForce,
    'quantity': order.quantity,
  };
  if (order.type == 'LIMIT' && order.limitPrice != null) {
    body['limitPrice'] = order.limitPrice!.toStringAsFixed(4);
  }
  return body;
}

class EmptyTradingService extends TradingService {
  @override
  Future<List<TradingOrder>> fetchOrders({bool allowCached = true}) async => [];

  @override
  Future<TradingAccountSnapshot?> fetchAccountSnapshot({
    bool allowCached = true,
  }) async => TradingAccountSnapshot.fromJson({
    'balances': {
      'cashBalance': 250000,
      'buyingPower': 250000,
      'frozenBalance': 1200,
    },
    'pnl': {'realizedPnl': 860.5},
    'positions': [],
  });

  @override
  Future<List<AccountTransaction>> fetchTransactions() async => [];
}

Future<void> pumpTrade(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  List<StockQuote> stocks = const [],
  List<TradingOrder> orders = const [],
  void Function(StockQuote stock, {required bool isBuy})? onOpen,
}) async {
  SharedPreferences.setMockInitialValues({});
  FlutterSecureStorage.setMockInitialValues({});
  setView(tester, size);
  await tester.pumpWidget(
    host(
      TradingCenterPage(
        tradingService: EmptyTradingService(),
        stocks: stocks,
        positions: const {},
        orders: orders,
        institutionalStocks: const [],
        ipos: const [],
        ipoApplications: const [],
        onTrade: (_) {},
        onOpenOrderTicket: onOpen,
        onApplyIpo: (_) {},
        onAlertsTap: () {},
        notificationCount: 0,
        indexQuotes: const {},
        onViewMarkets: () {},
        marketOpen: true,
      ),
      size: size,
    ),
  );
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  tearDown(() {
    StockDetailPage.debugNextConfirmedOrder = null;
  });

  testWidgets('trade overview shows real empty states and Buy/Sell', (
    tester,
  ) async {
    await pumpTrade(tester, size: const Size(390, 844));
    expect(find.text('Available Funds'), findsWidgets);
    expect(find.text('Frozen Funds'), findsOneWidget);
    expect(find.text('Buy'), findsWidgets);
    expect(find.text('Sell'), findsWidgets);
    expect(find.text('No orders yet'), findsOneWidget);
    await reveal(
      tester,
      find.textContaining('No open positions'),
      scrollKey: const Key('trade-overview'),
    );
    expect(find.textContaining('No open positions'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await disposeTree(tester);
  });

  testWidgets('unsupported products are omitted from the trade picker', (
    tester,
  ) async {
    await pumpTrade(
      tester,
      stocks: [
        equity(symbol: 'NIFTYFUT', name: 'Nifty Future', category: 'F&O'),
        equity(),
      ],
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Buy'));
    await pumpFrames(tester);
    expect(find.text('RELIANCE'), findsOneWidget);
    expect(find.text('NIFTYFUT'), findsNothing);
    await disposeTree(tester);
  });

  testWidgets('empty picker stays honest when nothing is tradable', (
    tester,
  ) async {
    await pumpTrade(
      tester,
      stocks: [
        equity(symbol: 'NIFTYFUT', name: 'Nifty Future', category: 'F&O'),
      ],
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Sell'));
    await pumpFrames(tester);
    expect(
      find.textContaining('Unsupported products cannot be ordered'),
      findsOneWidget,
    );
    await disposeTree(tester);
  });

  testWidgets('stock detail keeps MARKET/LIMIT DAY/IOC/FOK and payload keys', (
    tester,
  ) async {
    setView(tester, const Size(390, 844));
    final placed = <TradingOrder>[];
    await tester.pumpWidget(
      host(
        StockDetailPage(
          stock: equity(),
          marketOpen: true,
          tradingService: EmptyTradingService(),
          onOrderPlaced: (order) async {
            placed.add(order);
            return null;
          },
        ),
      ),
    );
    await pumpFrames(tester);
    await reveal(tester, find.text('Place Order'));
    expect(find.text('Place Order'), findsOneWidget);
    expect(find.text('Buy'), findsWidgets);
    expect(find.text('Sell'), findsWidgets);
    expect(find.text('Market Order'), findsOneWidget);
    expect(find.text('Limit Order'), findsOneWidget);
    expect(find.text('DAY'), findsOneWidget);
    expect(find.text('IOC'), findsOneWidget);
    expect(find.text('FOK'), findsOneWidget);
    await reveal(tester, find.text('Fees'));
    expect(find.text('Fees'), findsWidgets);
    expect(find.text(formatPrice(0)), findsWidgets);
    expect(find.text('Limit Price'), findsNothing);

    await reveal(tester, find.text('Limit Order'));
    await tester.tap(find.text('Limit Order'));
    await pumpFrames(tester);
    await reveal(tester, find.text('Limit Price'));
    expect(find.text('Limit Price'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Limit Price'),
      '1450',
    );
    await tester.tap(find.text('IOC'));
    await pumpFrames(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Quantity'), '3');
    await reveal(tester, find.byTooltip('Sell'));
    await tester.tap(find.byTooltip('Sell'));
    await pumpFrames(tester);
    expect(find.widgetWithText(TextField, 'Quantity'), findsOneWidget);
    expect(find.text('1450'), findsOneWidget);

    await openConfirm(tester, buy: false);
    expect(placed, isEmpty);
    expect(find.text('Confirm Sell'), findsOneWidget);
    expect(find.text('MARKET'), findsNothing);
    expect(find.text('LIMIT'), findsOneWidget);
    expect(find.text('IOC'), findsWidgets);
    expect(find.text('3'), findsWidgets);
    await tester.tap(confirmButton());
    await pumpFrames(tester);
    expect(placed, hasLength(1));
    final body = apiPayload(placed.single);
    expect(
      body.keys,
      unorderedEquals([
        'clientOrderId',
        'exchange',
        'symbol',
        'side',
        'type',
        'timeInForce',
        'quantity',
        'limitPrice',
      ]),
    );
    expect(body['side'], 'SELL');
    expect(body['type'], 'LIMIT');
    expect(body['timeInForce'], 'IOC');
    expect(body['quantity'], 3);
    expect(body['limitPrice'], '1450.0000');
    expect(body['symbol'], 'RELIANCE');
    expect(body['exchange'], 'NSE');
    expect(body['clientOrderId'], isNotEmpty);
    await disposeTree(tester);
  });

  testWidgets('preview does not submit and confirm sends once', (tester) async {
    setView(tester, const Size(390, 844));
    var submits = 0;
    final gate = Completer<String?>();
    await tester.pumpWidget(
      host(
        StockDetailPage(
          stock: equity(),
          marketOpen: true,
          onOrderPlaced: (_) {
            submits += 1;
            return gate.future;
          },
        ),
      ),
    );
    await pumpFrames(tester);
    expect(submits, 0);
    await openConfirm(tester);
    expect(submits, 0);
    expect(find.text('Confirm Buy'), findsOneWidget);
    await tester.tap(confirmButton());
    await tester.pump();
    await tester.tap(confirmButton());
    await tester.pump();
    expect(submits, 1);
    expect(find.text('Submitting...'), findsOneWidget);
    gate.complete(null);
    await pumpFrames(tester);
    expect(submits, 1);
    expect(find.textContaining('order submitted'), findsOneWidget);
    await disposeTree(tester);
  });

  testWidgets('timeout retry reuses the same clientOrderId', (tester) async {
    setView(tester, const Size(390, 844));
    final ids = <String?>[];
    await tester.pumpWidget(
      host(
        StockDetailPage(
          stock: equity(),
          marketOpen: true,
          onOrderPlaced: (order) async {
            ids.add(order.clientOrderId);
            if (ids.length == 1) {
              return 'Order confirmation is unavailable. Check your orders before submitting again.';
            }
            return null;
          },
        ),
      ),
    );
    await pumpFrames(tester);
    await tester.tap(find.text('BUY'));
    await pumpFrames(tester);
    await tester.tap(confirmButton());
    await pumpFrames(tester);
    expect(
      find.textContaining('Order confirmation is unavailable'),
      findsOneWidget,
    );
    await tester.tap(confirmButton());
    await pumpFrames(tester);
    expect(ids, hasLength(2));
    expect(ids.first, ids.last);
    await disposeTree(tester);
  });

  testWidgets('market closed ticket explains why confirm is blocked', (
    tester,
  ) async {
    setView(tester, const Size(390, 844));
    var submits = 0;
    await tester.pumpWidget(
      host(
        StockDetailPage(
          stock: equity(),
          marketOpen: false,
          marketHours: '09:15 - 15:30 IST',
          onOrderPlaced: (_) async {
            submits += 1;
            return null;
          },
        ),
      ),
    );
    await pumpFrames(tester);
    expect(find.text('NSE Closed'), findsWidgets);
    await tester.tap(find.text('BUY'));
    await pumpFrames(tester);
    expect(find.text('Confirm Buy'), findsOneWidget);
    expect(find.textContaining('session is closed'), findsWidgets);
    final confirm = tester.widget<FilledButton>(confirmButton());
    expect(confirm.onPressed, isNull);
    expect(submits, 0);
    await disposeTree(tester);
  });

  testWidgets('shows buying power and holdings errors from current submit', (
    tester,
  ) async {
    setView(tester, const Size(390, 844));
    await tester.pumpWidget(
      host(
        StockDetailPage(
          stock: equity(),
          marketOpen: true,
          onOrderPlaced: (order) async {
            if (order.isBuy) {
              return 'Insufficient buying power. Available: ${formatPrice(100)}';
            }
            return 'Insufficient holdings. Available: 0';
          },
        ),
      ),
    );
    await pumpFrames(tester);
    await tester.tap(find.text('BUY'));
    await pumpFrames(tester);
    await tester.tap(confirmButton());
    await pumpFrames(tester);
    expect(find.textContaining('Insufficient buying power'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await pumpFrames(tester);
    await tester.tap(find.text('SELL'));
    await pumpFrames(tester);
    await tester.tap(confirmButton());
    await pumpFrames(tester);
    expect(find.textContaining('Insufficient holdings'), findsOneWidget);
    await disposeTree(tester);
  });

  testWidgets('unsupported product has no ticket', (tester) async {
    setView(tester, const Size(320, 568));
    await tester.pumpWidget(
      host(
        StockDetailPage(
          stock: equity(
            symbol: 'NIFTYFUT',
            name: 'Nifty Future',
            category: 'F&O',
          ),
          marketOpen: true,
          onOrderPlaced: (_) async => null,
        ),
        size: const Size(320, 568),
        textScale: 1.3,
      ),
    );
    await pumpFrames(tester);
    expect(find.byType(BrowseOnlyBanner), findsOneWidget);
    expect(find.text('BUY'), findsNothing);
    expect(find.text('SELL'), findsNothing);
    expect(find.text('Place Order'), findsNothing);
    expect(tester.takeException(), isNull);
    await disposeTree(tester);
  });

  testWidgets('OPEN FILLED and REJECTED responses stay honest', (tester) async {
    setView(tester, const Size(390, 844));
    Future<void> run(TradingOrder confirmed, String expected) async {
      StockDetailPage.debugNextConfirmedOrder = confirmed;
      await tester.pumpWidget(
        host(
          StockDetailPage(
            stock: equity(),
            marketOpen: true,
            onOrderPlaced: (_) async => null,
          ),
        ),
      );
      await pumpFrames(tester);
      await tester.tap(find.text('BUY'));
      await pumpFrames(tester);
      await tester.tap(confirmButton());
      await pumpFrames(tester);
      expect(find.textContaining(expected), findsOneWidget);
      await disposeTree(tester);
    }

    await run(
      TradingOrder(
        status: 'OPEN',
        symbol: 'RELIANCE',
        isBuy: true,
        quantity: 1,
        price: 1456,
        placedAt: DateTime.now(),
      ),
      'Order open',
    );
    await run(
      TradingOrder(
        status: 'FILLED',
        filledQuantity: 1,
        averageFillPrice: 1456,
        symbol: 'RELIANCE',
        isBuy: true,
        quantity: 1,
        price: 1456,
        placedAt: DateTime.now(),
      ),
      'Completed',
    );
    await run(
      TradingOrder(
        status: 'REJECTED',
        rejectionReason: 'Insufficient liquidity',
        symbol: 'RELIANCE',
        isBuy: true,
        quantity: 1,
        price: 1456,
        placedAt: DateTime.now(),
      ),
      'Insufficient liquidity',
    );
  });

  testWidgets('reduced motion and 320 width keep the ticket usable', (
    tester,
  ) async {
    setView(tester, const Size(320, 568));
    await tester.pumpWidget(
      host(
        StockDetailPage(
          stock: equity(),
          marketOpen: true,
          onOrderPlaced: (_) async => null,
        ),
        size: const Size(320, 568),
        textScale: 1.3,
        reduceMotion: true,
      ),
    );
    await pumpFrames(tester);
    await reveal(tester, find.text('Limit Order'));
    await tester.tap(find.text('Limit Order'));
    await pumpFrames(tester);
    expect(find.text('Limit Price'), findsOneWidget);
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    await tester.pump();
    expect(find.text('BUY'), findsOneWidget);
    expect(find.text('SELL'), findsOneWidget);
    expect(tester.takeException(), isNull);
    tester.view.viewInsets = FakeViewPadding.zero;
    await disposeTree(tester);
  });

  testWidgets('stock detail trade entry can return to the previous page', (
    tester,
  ) async {
    setView(tester, const Size(375, 667));
    await tester.pumpWidget(
      host(
        Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () {
                    Navigator.push<void>(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => StockDetailPage(
                          stock: equity(),
                          initialIsBuy: false,
                          marketOpen: true,
                          onOrderPlaced: (_) async => null,
                        ),
                      ),
                    );
                  },
                  child: const Text('Open RELIANCE'),
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('Open RELIANCE'));
    await pumpFrames(tester);
    await reveal(tester, find.text('Place Order'));
    expect(find.text('Place Order'), findsOneWidget);
    expect(find.text('Sell'), findsWidgets);
    await tester.pageBack();
    await pumpFrames(tester);
    expect(find.text('Open RELIANCE'), findsOneWidget);
    await disposeTree(tester);
  });
}
