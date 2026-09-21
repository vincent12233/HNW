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
    expect(snapshot.totalAsset, isNull);
    expect(snapshot.unrealizedPnl, isNull);
  });

  test('keeps API totalAsset and unrealizedPnl including zero', () {
    final snapshot = TradingAccountSnapshot.fromJson({
      'balances': {
        'cashBalance': '10.00',
        'buyingPower': '10.00',
        'frozenBalance': '0.00',
        'holdingsMarketValue': '0.00',
        'totalAsset': '0.00',
      },
      'pnl': {
        'realizedPnl': '1.00',
        'unrealizedPnl': '0.00',
        'totalPnl': '1.00',
      },
      'positions': [],
    });

    expect(snapshot.totalAsset, 0);
    expect(snapshot.unrealizedPnl, 0);
    expect(snapshot.totalAssetOr(99), 0);
    expect(snapshot.unrealizedPnlOr(99), 0);
  });

  test('falls back when authoritative fields are missing', () {
    final snapshot = TradingAccountSnapshot.fromJson({
      'balances': {
        'cashBalance': '80.00',
        'buyingPower': '80.00',
        'frozenBalance': '0.00',
      },
      'pnl': {'realizedPnl': '2'},
      'positions': [],
    });

    expect(snapshot.totalAsset, isNull);
    expect(snapshot.unrealizedPnl, isNull);
    expect(snapshot.totalAssetOr(125), 125);
    expect(snapshot.unrealizedPnlOr(-4), -4);
  });

  test('malformed payload does not throw', () {
    final snapshot = TradingAccountSnapshot.fromJson({
      'balances': {'cashBalance': '10', 'totalAsset': 'not-a-number'},
      'pnl': 'broken',
      'positions': [
        'bad-row',
        {
          'symbol': 'RELIANCE',
          'name': 'Reliance',
          'category': 'EQUITY',
          'quantity': 1,
          'averagePrice': '10',
          'exchange': 'NSE',
        },
      ],
    });

    expect(snapshot.totalAsset, isNull);
    expect(snapshot.unrealizedPnl, isNull);
    expect(snapshot.positions, isNotEmpty);
  });
}
