import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:india_trading_app/models/account_transaction.dart';
import 'package:india_trading_app/models/trading_order.dart';
import 'package:india_trading_app/pages/trading_center_page.dart';
import 'package:india_trading_app/services/trading_service.dart';

class FailedTradingService extends TradingService {
  bool recover = false;
  @override
  Future<List<TradingOrder>> fetchOrders({bool allowCached = true}) async {
    expect(allowCached, isFalse);
    if (!recover) throw Exception('offline');
    return [];
  }

  @override
  Future<TradingAccountSnapshot?> fetchAccountSnapshot({
    bool allowCached = true,
  }) async {
    expect(allowCached, isFalse);
    if (!recover) throw Exception('offline');
    return TradingAccountSnapshot.fromJson({'balances': {}, 'positions': []});
  }

  @override
  Future<List<AccountTransaction>> fetchTransactions() async => [];
}

void main() {
  testWidgets('failed trading refresh shows failure and retry recovers', (
    tester,
  ) async {
    final service = FailedTradingService();
    await tester.pumpWidget(
      MaterialApp(
        home: TradingCenterPage(
          tradingService: service,
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
    await tester.pumpAndSettle();
    expect(
      find.text('Orders and balances could not be updated.'),
      findsOneWidget,
    );
    expect(
      find.text('Trading data is temporarily unavailable.'),
      findsOneWidget,
    );
    service.recover = true;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(
      find.text('Orders and balances could not be updated.'),
      findsNothing,
    );
    expect(find.text('Trading data is temporarily unavailable.'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
