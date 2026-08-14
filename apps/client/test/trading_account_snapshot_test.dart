import 'package:flutter_test/flutter_test.dart';
import 'package:india_trading_app/services/trading_service.dart';

void main() {
  test('keeps cash, buying power and frozen funds separate', () {
    final snapshot = TradingAccountSnapshot.fromJson({
      'balances': {
        'cashBalance': '100000.00',
        'buyingPower': '75000.00',
        'frozenBalance': '25000.00',
      },
      'positions': [],
      'pnl': {'realizedPnl': '0'},
    });

    expect(snapshot.cashBalance, 100000);
    expect(snapshot.buyingPower, 75000);
    expect(snapshot.frozenBalance, 25000);
  });

  test('uses cash as buying power for an older cached response', () {
    final snapshot = TradingAccountSnapshot.fromJson({
      'balances': {'cashBalance': '5000.00'},
      'positions': [],
      'pnl': {'realizedPnl': '0'},
    });

    expect(snapshot.buyingPower, 5000);
    expect(snapshot.frozenBalance, 0);
  });
}
