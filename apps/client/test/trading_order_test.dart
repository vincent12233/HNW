import 'package:flutter_test/flutter_test.dart';
import 'package:india_trading_app/models/trading_order.dart';

void main() {
  test('parses partially filled limit order without losing total quantity', () {
    final order = TradingOrder.fromApiJson({
      'id': 'order-1',
      'clientOrderId': 'APP-1-RELIANCE',
      'status': 'PARTIALLY_FILLED',
      'side': 'BUY',
      'type': 'LIMIT',
      'timeInForce': 'DAY',
      'quantity': 10,
      'filledQuantity': 4,
      'limitPrice': '1250.50',
      'averageFillPrice': '1248.25',
      'placedAt': '2026-08-12T09:20:00.000Z',
      'updatedAt': '2026-08-12T09:21:00.000Z',
      'completedAt': '2026-08-12T09:22:00.000Z',
      'instrument': {'symbol': 'RELIANCE', 'exchange': 'BSE'},
      'trades': [
        {
          'executionId': 'INT-EXEC-1',
          'quantity': 4,
          'price': '1248.25',
          'grossAmount': '4993.00',
          'fees': '2.50',
          'netAmount': '4995.50',
          'executedAt': '2026-08-12T09:20:30.000Z',
        },
      ],
    });

    expect(order.orderId, 'order-1');
    expect(order.symbol, 'RELIANCE');
    expect(order.exchange, 'BSE');
    expect(order.type, 'LIMIT');
    expect(order.timeInForce, 'DAY');
    expect(order.quantity, 10);
    expect(order.filledQuantity, 4);
    expect(order.remainingQuantity, 6);
    expect(order.limitPrice, 1250.50);
    expect(order.averageFillPrice, 1248.25);
    expect(order.price, 1248.25);
    expect(order.isActive, isTrue);
    expect(order.updatedAt, DateTime.parse('2026-08-12T09:21:00.000Z'));
    expect(order.completedAt, DateTime.parse('2026-08-12T09:22:00.000Z'));
    expect(order.fills, hasLength(1));
    expect(order.fills.first.executionId, 'INT-EXEC-1');
    expect(order.fills.first.quantity, 4);
    expect(order.fills.first.fees, 2.50);
  });

  test('keeps unfilled open limit order quantity and limit price', () {
    final order = TradingOrder.fromApiJson({
      'id': 'order-2',
      'status': 'OPEN',
      'side': 'SELL',
      'type': 'LIMIT',
      'timeInForce': 'IOC',
      'quantity': 8,
      'filledQuantity': 0,
      'limitPrice': '900',
      'placedAt': '2026-08-12T09:20:00.000Z',
      'instrument': {'symbol': 'TCS'},
    });

    expect(order.quantity, 8);
    expect(order.filledQuantity, 0);
    expect(order.remainingQuantity, 8);
    expect(order.price, 900);
    expect(order.isBuy, isFalse);
    expect(order.isLimit, isTrue);
  });

  test('preserves terminal cancellation and rejection details', () {
    final cancelled = TradingOrder.fromApiJson({
      'id': 'order-3',
      'status': 'CANCELLED',
      'side': 'BUY',
      'type': 'LIMIT',
      'timeInForce': 'IOC',
      'quantity': 10,
      'filledQuantity': 3,
      'limitPrice': '101.00',
      'averageFillPrice': '100.75',
      'instrument': {'symbol': 'SBIN'},
    });
    final rejected = TradingOrder.fromApiJson({
      'id': 'order-4',
      'status': 'REJECTED',
      'side': 'BUY',
      'type': 'LIMIT',
      'timeInForce': 'FOK',
      'quantity': 5,
      'filledQuantity': 0,
      'limitPrice': '500.00',
      'rejectionReason': 'Insufficient liquidity',
      'instrument': {'symbol': 'INFY'},
    });

    expect(cancelled.remainingQuantity, 7);
    expect(cancelled.averageFillPrice, 100.75);
    expect(rejected.rejectionReason, 'Insufficient liquidity');
  });
}
