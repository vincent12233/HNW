import 'package:flutter_test/flutter_test.dart';
import 'package:india_trading_app/models/trading_order.dart';

void main() {
  Map<String, dynamic> response() => {
    'order': {
      'id': 'order-1',
      'clientOrderId': 'request-1',
      'status': 'OPEN',
      'side': 'BUY',
      'quantity': 10,
      'filledQuantity': 0,
      'instrument': {'symbol': 'TCS', 'exchange': 'BSE'},
    },
  };
  test('confirmation preserves actual status and exchange', () {
    final order = TradingOrder.fromConfirmation(response(), 'request-1');
    expect(order.status, 'OPEN');
    expect(order.exchange, 'BSE');
    expect(order.filledQuantity, 0);
  });
  test('missing data and mismatched requests cannot confirm a draft', () {
    for (final value in [
      null,
      {},
      {'order': {}},
      response(),
    ]) {
      expect(
        () => TradingOrder.fromConfirmation(value, 'another-request'),
        throwsFormatException,
      );
    }
    final missingStatus = response();
    (missingStatus['order'] as Map).remove('status');
    expect(
      () => TradingOrder.fromConfirmation(missingStatus, 'request-1'),
      throwsFormatException,
    );
  });
  test(
    'confirmed order survives lagging refresh without clearing existing records',
    () {
      final order = TradingOrder.fromConfirmation(response(), 'request-1');
      final old = TradingOrder(
        symbol: 'OLD',
        isBuy: true,
        quantity: 1,
        price: 1,
        placedAt: DateTime(2026),
      );
      final rows = [old];
      final merged = mergeConfirmedOrder(order, rows);
      rows.clear();
      expect(merged, [order, old]);
      expect(mergeConfirmedOrder(order, merged), hasLength(2));
    },
  );
}
