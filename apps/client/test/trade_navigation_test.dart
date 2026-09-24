import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:india_trading_app/pages/trading_center_page.dart';
import 'package:india_trading_app/services/trading_service.dart';
import 'package:india_trading_app/models/trading_order.dart';
import 'package:india_trading_app/models/account_transaction.dart';
import 'package:india_trading_app/widgets/trading/orders_tab.dart';
import 'package:india_trading_app/widgets/trading/holdings_tab.dart';
import 'package:india_trading_app/widgets/trading/history_tab.dart';
import 'package:india_trading_app/widgets/trading/pending_center_tab.dart';
import 'package:india_trading_app/widgets/trading/funds_tab.dart';

class EmptyTradingService extends TradingService {
  @override
  Future<List<TradingOrder>> fetchOrders({bool allowCached = true}) async => [];
  @override
  Future<TradingAccountSnapshot?> fetchAccountSnapshot({
    bool allowCached = true,
  }) async =>
      TradingAccountSnapshot.fromJson({'balances': {}, 'positions': []});
  @override
  Future<List<AccountTransaction>> fetchTransactions() async => [];
}

void main() {
  testWidgets('trade actions and product tabs fit phone widths', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    for (final width in [320.0, 390.0, 430.0]) {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        MaterialApp(
          home: TradingCenterPage(
            tradingService: EmptyTradingService(),
            stocks: const [],
            positions: const {},
            orders: const [],
            institutionalStocks: const [],
            ipos: const [],
            ipoApplications: const [],
            onTrade: (_) {},
            onApplyIpo: (_) {},
            onAlertsTap: () {},
            notificationCount: 0,
            indexQuotes: const {},
            onViewMarkets: () {},
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(find.byIcon(Icons.shopping_cart_outlined), findsOneWidget);
      expect(find.byIcon(Icons.sell_outlined), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Overview'), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets(
    'trade module tabs scroll on a narrow screen and open their modules',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
      tester.view.physicalSize = const Size(320, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: TradingCenterPage(
            tradingService: EmptyTradingService(),
            stocks: const [],
            positions: const {},
            orders: const [],
            institutionalStocks: const [],
            ipos: const [],
            ipoApplications: const [],
            onTrade: (_) {},
            onApplyIpo: (_) {},
            onAlertsTap: () {},
            notificationCount: 0,
            indexQuotes: const {},
            onViewMarkets: () {},
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      final shortcutRow = find.byWidgetPredicate(
        (widget) =>
            widget is ListView && widget.scrollDirection == Axis.horizontal,
      );

      Future<void> tapChip(String label, int index) async {
        final finder = find.byKey(ValueKey('trade-shortcut-$index'));
        expect(finder, findsOneWidget);
        expect(
          find.descendant(of: finder, matching: find.text(label)),
          findsOneWidget,
        );
        await tester.dragUntilVisible(
          finder.first,
          shortcutRow.first,
          const Offset(-60, 0),
        );
        await tester.pumpAndSettle();
        await tester.tap(finder.first);
        await tester.pump(const Duration(seconds: 1));
      }

      for (final entry in <(String, int, Type)>[
        ('Orders', 4, OrdersTab),
        ('Pending', 3, PendingCenterTab),
        ('Holdings', 2, HoldingsTab),
        ('History', 7, HistoryTab),
      ]) {
        await tapChip(entry.$1, entry.$2);
        expect(find.byType(entry.$3), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      await tester.tap(find.byTooltip('Account Ledger'));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(FundsTab), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 30));
    },
  );
}
