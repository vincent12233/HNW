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
  testWidgets(
    'all four trade shortcuts fit a narrow screen and open their modules',
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
            pendingOrders: const [],
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
      for (final entry in <String, Type>{
        'Orders': OrdersTab,
        'Pending': PendingCenterTab,
        'Holdings': HoldingsTab,
        'History': HistoryTab,
      }.entries) {
        final label = find.text(entry.key).first;
        expect(tester.getCenter(label).dx, inInclusiveRange(0, 320));
        await tester.tap(label);
        await tester.pump(const Duration(seconds: 1));
        expect(find.byType(entry.value), findsOneWidget);
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
