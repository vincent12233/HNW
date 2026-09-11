import 'package:flutter_test/flutter_test.dart';
import 'package:india_trading_app/models/trading_order.dart';
import 'package:india_trading_app/pages/stock_detail_page.dart';

void main() {
  TradingOrder order({
    required String status,
    String timeInForce = 'DAY',
    int quantity = 10,
    int filledQuantity = 0,
    double? averageFillPrice,
    String? rejectionReason,
  }) {
    return TradingOrder(
      status: status,
      timeInForce: timeInForce,
      filledQuantity: filledQuantity,
      averageFillPrice: averageFillPrice,
      rejectionReason: rejectionReason,
      symbol: 'SBIN',
      isBuy: true,
      quantity: quantity,
      price: 100,
      placedAt: DateTime.parse('2026-08-12T09:20:00Z'),
    );
  }

  test('shows completed fill quantity and average fill price', () {
    final message = orderResultMessage(
      order(status: 'FILLED', filledQuantity: 10, averageFillPrice: 99.75),
    );

    expect(message, contains('Completed'));
    expect(message, contains('Filled 10/10'));
    expect(message, contains('Avg.'));
  });

  test('shows IOC partial fill with cancelled remainder', () {
    final message = orderResultMessage(
      order(
        status: 'CANCELLED',
        timeInForce: 'IOC',
        filledQuantity: 4,
        averageFillPrice: 100.25,
      ),
    );

    expect(message, contains('Partially filled'));
    expect(message, contains('Filled 4/10'));
    expect(message, contains('Remaining 6 cancelled'));
  });

  test('shows unfilled FOK as cancelled', () {
    final message = orderResultMessage(
      order(status: 'CANCELLED', timeInForce: 'FOK'),
    );

    expect(message, 'Order cancelled • No shares filled');
  });

  test('shows rejection reason when returned by backend', () {
    final message = orderResultMessage(
      order(status: 'REJECTED', rejectionReason: 'Insufficient liquidity'),
    );

    expect(message, 'Order rejected • Insufficient liquidity');
  });
}
