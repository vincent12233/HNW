import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:india_trading_app/models/trading_order.dart';
import 'package:india_trading_app/pages/stock_detail_page.dart';
import 'package:india_trading_app/theme/app_theme.dart';
import 'package:india_trading_app/widgets/trading/orders_tab.dart';
import 'package:india_trading_app/widgets/trading/standard_order_details_sheet.dart';

import 'trade_order_ui_phase_d1_test.dart';

TradingOrder sampleOrder({
  String status = 'OPEN',
  String symbol = 'RELIANCE',
  String exchange = 'NSE',
  bool isBuy = true,
  String type = 'LIMIT',
  String tif = 'DAY',
  int quantity = 10,
  int filled = 0,
  String? orderId = 'ord-1',
  String? clientOrderId = 'client-order-abcdefghijklmnopqrstuvwxyz',
  String? rejectionReason,
  double? limitPrice = 1450,
  double? averageFillPrice,
  List<TradingFill> fills = const [],
}) {
  return TradingOrder(
    orderId: orderId,
    clientOrderId: clientOrderId,
    status: status,
    type: type,
    timeInForce: tif,
    symbol: symbol,
    exchange: exchange,
    isBuy: isBuy,
    quantity: quantity,
    filledQuantity: filled,
    price: limitPrice ?? 0,
    limitPrice: type == 'LIMIT' ? limitPrice : null,
    averageFillPrice: averageFillPrice,
    rejectionReason: rejectionReason,
    placedAt: DateTime.utc(2026, 8, 12, 3, 50),
    updatedAt: DateTime.utc(2026, 8, 12, 3, 55),
    fills: fills,
  );
}

Future<void> pumpOrderList(
  WidgetTester tester, {
  required List<TradingOrder> orders,
  Size size = const Size(390, 844),
  double textScale = 1,
  bool reduceMotion = false,
  Future<String?> Function(TradingOrder order)? onCancel,
}) async {
  setView(tester, size);
  await tester.pumpWidget(
    host(
      Scaffold(
        body: OrdersTab(orders: orders, onCancel: onCancel),
      ),
      size: size,
      textScale: textScale,
      reduceMotion: reduceMotion,
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('order list shows every current status without inventing PENDING', (
    tester,
  ) async {
    await pumpOrderList(
      tester,
      orders: [
        sampleOrder(status: 'OPEN', symbol: 'OPENCO'),
        sampleOrder(
          status: 'PARTIALLY_FILLED',
          symbol: 'PARTCO',
          filled: 4,
          orderId: 'ord-p',
        ),
        sampleOrder(
          status: 'FILLED',
          symbol: 'FILLCO',
          filled: 10,
          orderId: 'ord-f',
        ),
        sampleOrder(status: 'CANCELLED', symbol: 'CANCCO', orderId: 'ord-c'),
        sampleOrder(
          status: 'REJECTED',
          symbol: 'REJCO',
          orderId: 'ord-r',
          rejectionReason: 'Buying power exceeded',
        ),
      ],
    );
    expect(find.text('OPENCO'), findsOneWidget);
    expect(find.text('Open'), findsWidgets);
    expect(find.text('PARTCO'), findsOneWidget);
    expect(find.textContaining('4 / 10 filled'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('FILLCO'),
      240,
      scrollable: find.descendant(
        of: find.byKey(const Key('orders-list')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.text('FILLCO'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('CANCCO'),
      240,
      scrollable: find.descendant(
        of: find.byKey(const Key('orders-list')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.text('Cancelled'), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('REJCO'),
      240,
      scrollable: find.descendant(
        of: find.byKey(const Key('orders-list')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.text('Buying power exceeded'), findsOneWidget);
    expect(find.textContaining('sample order'), findsNothing);
    expect(tester.takeException(), isNull);
    await disposeTree(tester);
  });

  testWidgets('PENDING filter stays empty when the API has none', (tester) async {
    await pumpOrderList(
      tester,
      orders: [sampleOrder(status: 'FILLED', filled: 10)],
    );
    await tester.tap(find.byKey(const ValueKey('order-filter-status-OPEN_PENDING')));
    await tester.pump();
    expect(find.text('RELIANCE'), findsNothing);
    expect(find.text('No matching orders'), findsOneWidget);
    expect(find.textContaining('sample'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('order-filter-status-FILLED')));
    await tester.pump();
    expect(find.text('RELIANCE'), findsOneWidget);
    await tester.tap(find.text('Clear filters'));
    await tester.pump();
    expect(find.text('RELIANCE'), findsOneWidget);
    await disposeTree(tester);
  });

  testWidgets('details show real fields and do not invent fills', (tester) async {
    final order = sampleOrder(
      status: 'PARTIALLY_FILLED',
      filled: 4,
      averageFillPrice: 1448,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showStandardOrderDetails(context, order: order),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('RELIANCE'), findsWidgets);
    expect(find.text('BUY'), findsOneWidget);
    expect(find.text('Partially Filled'), findsWidgets);
    expect(find.text('Limit Order'), findsWidgets);
    expect(find.text('DAY'), findsWidgets);
    expect(find.text('4'), findsWidgets);
    expect(find.text('6'), findsOneWidget);
    expect(find.text('No execution details are available for this order.'), findsNothing);
    expect(
      find.text('Filled 4/10. No execution details are available.'),
      findsOneWidget,
    );
    expect(find.text('client-order-abcdefghijklmnopqrstuvwxyz'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('FILLED REJECTED and CANCELLED hide cancel', (tester) async {
    for (final status in ['FILLED', 'CANCELLED', 'REJECTED']) {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showStandardOrderDetails(
                  context,
                  order: sampleOrder(status: status, filled: status == 'FILLED' ? 10 : 0),
                  onCancel: (_) async => fail('cancel must not be offered'),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Cancel Order'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('cancel confirms once and waits for the server', (tester) async {
    final pending = Completer<void>();
    var calls = 0;
    final order = sampleOrder();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showStandardOrderDetails(
                context,
                order: order,
                onCancel: (_) async {
                  calls += 1;
                  await pending.future;
                  return null;
                },
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Cancel Order'));
    await tester.tap(find.text('Cancel Order'));
    await tester.pumpAndSettle();
    expect(find.text('Confirm cancel'), findsOneWidget);
    expect(find.text('Keep order'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Confirm cancel'));
    await tester.pump();
    expect(find.text('Cancelling...'), findsOneWidget);
    expect(find.text('RELIANCE order cancelled'), findsNothing);
    await tester.tap(
      find.widgetWithText(OutlinedButton, 'Cancelling...'),
      warnIfMissed: false,
    );
    await tester.pump();
    expect(calls, 1);
    pending.complete();
    await tester.pumpAndSettle();
    expect(find.text('RELIANCE order cancelled'), findsOneWidget);
    expect(calls, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('cancel failure keeps the order and shows the server error', (
    tester,
  ) async {
    var calls = 0;
    await pumpOrderList(
      tester,
      orders: [sampleOrder(status: 'OPEN')],
      onCancel: (_) async {
        calls += 1;
        return 'Order already filled';
      },
    );
    expect(find.text('RELIANCE'), findsWidgets);
    await tester.tap(find.text('Cancel').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Confirm cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Order already filled'), findsOneWidget);
    expect(find.text('RELIANCE'), findsWidgets);
    expect(find.text('Open'), findsWidgets);
    expect(find.text('Cancel'), findsWidgets);
    expect(calls, 1);
    await disposeTree(tester);
  });

  testWidgets('D.1 success opens the shared order details', (tester) async {
    StockDetailPage.debugNextConfirmedOrder = sampleOrder(
      status: 'OPEN',
      clientOrderId: 'cid-1',
    );
    setView(tester, const Size(390, 844));
    await tester.pumpWidget(
      host(
        StockDetailPage(
          stock: equity(),
          marketOpen: true,
          tradingService: EmptyTradingService(),
          onOrderPlaced: (_) async => null,
        ),
      ),
    );
    await pumpFrames(tester);
    await tester.tap(find.text('BUY'));
    await pumpFrames(tester);
    await tester.tap(confirmButton());
    await pumpFrames(tester);
    expect(find.textContaining('Order open'), findsOneWidget);
    await tester.tap(find.text('View Order'));
    await tester.pumpAndSettle();
    expect(find.text('Limit Order'), findsWidgets);
    expect(find.text('Remaining Quantity'), findsOneWidget);
    expect(tester.takeException(), isNull);
    StockDetailPage.debugNextConfirmedOrder = null;
    await disposeTree(tester);
  });

  testWidgets('reduced motion and 320 keep the order list usable', (
    tester,
  ) async {
    await pumpOrderList(
      tester,
      orders: [
        sampleOrder(symbol: 'VERYLONGSYMBOLNAME'),
        sampleOrder(
          status: 'FILLED',
          symbol: 'FILLCO',
          orderId: 'ord-2',
          filled: 10,
        ),
      ],
      size: const Size(320, 844),
      textScale: 1.3,
      reduceMotion: true,
    );
    expect(find.text('VERYLONGSYMBOLNAME'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await disposeTree(tester);
  });

  testWidgets('order cards fit 320 width at text scale 1.3', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      host(
        const Scaffold(
          body: OrdersTab(
            orders: [],
          ),
        ),
        size: const Size(320, 568),
        textScale: 1.3,
        reduceMotion: true,
      ),
    );
    await tester.pump();
    expect(find.text('No orders'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(
      host(
        Scaffold(
          body: OrdersTab(
            orders: [
              sampleOrder(symbol: 'VERYLONGSYMBOLNAME'),
              sampleOrder(
                status: 'PARTIALLY_FILLED',
                symbol: 'PARTCO',
                filled: 4,
                orderId: 'ord-p',
              ),
            ],
          ),
        ),
        size: const Size(320, 568),
        textScale: 1.3,
      ),
    );
    await tester.pump();
    expect(find.text('VERYLONGSYMBOLNAME'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('PARTCO'),
      180,
      scrollable: find.descendant(
        of: find.byKey(const Key('orders-list')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.textContaining('4 / 10 filled'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await disposeTree(tester);
  });

  testWidgets('orders tab shows loading empty error and retry', (tester) async {
    setView(tester, const Size(390, 844));
    await tester.pumpWidget(
      host(const Scaffold(body: OrdersTab(orders: [], loading: true))),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpWidget(
      host(const Scaffold(body: OrdersTab(orders: []))),
    );
    await tester.pump();
    expect(find.text('No orders'), findsOneWidget);
    expect(find.textContaining('sample orders'), findsOneWidget);
    var retries = 0;
    await tester.pumpWidget(
      host(
        Scaffold(
          body: OrdersTab(
            orders: const [],
            failed: true,
            onRefresh: () async {
              retries += 1;
            },
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Orders could not be loaded'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(retries, 1);
    await disposeTree(tester);
  });

  testWidgets('refresh does not start a second request while in flight', (
    tester,
  ) async {
    var calls = 0;
    final gate = Completer<void>();
    setView(tester, const Size(390, 844));
    await tester.pumpWidget(
      host(
        Scaffold(
          body: OrdersTab(
            orders: [sampleOrder()],
            onRefresh: () async {
              calls += 1;
              await gate.future;
            },
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Refresh orders'));
    await tester.pump();
    await tester.tap(find.byTooltip('Refresh orders'), warnIfMissed: false);
    await tester.pump();
    expect(calls, 1);
    gate.complete();
    await tester.pump();
    expect(calls, 1);
    await disposeTree(tester);
  });

  test('order payload keys stay on the current D.1 contract', () {
    final body = apiPayload(sampleOrder());
    expect(body.keys.toSet(), {
      'clientOrderId',
      'exchange',
      'symbol',
      'side',
      'type',
      'timeInForce',
      'quantity',
      'limitPrice',
    });
    expect(body['side'], 'BUY');
    expect(body['type'], 'LIMIT');
    expect(body['timeInForce'], 'DAY');
  });
}
