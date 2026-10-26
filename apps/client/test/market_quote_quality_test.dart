import 'package:flutter_test/flutter_test.dart';
import 'package:india_trading_app/services/market_socket_service.dart';

void main() {
  test('sequence gate rejects duplicate and out-of-order quote delivery', () {
    final gate = MarketQuoteFreshnessGate();
    final at = DateTime.utc(2026, 10, 25, 4);
    const key = 'STOCK:NSE:RELIANCE';

    expect(gate.accept(key, at, 10), isTrue);
    expect(gate.accept(key, at.add(const Duration(seconds: 1)), 10), isFalse);
    expect(gate.accept(key, at.add(const Duration(seconds: 2)), 9), isFalse);
    expect(gate.accept(key, at.add(const Duration(seconds: 3)), 11), isTrue);
  });

  test('sequence gap requests a snapshot recovery signal', () {
    final gate = MarketQuoteFreshnessGate();
    final at = DateTime.utc(2026, 10, 25, 4);
    const key = 'STOCK:NSE:TCS';

    expect(gate.accept(key, at, 4), isTrue);
    expect(gate.hasSequenceGap(key, 5), isFalse);
    expect(gate.hasSequenceGap(key, 7), isTrue);
  });
}
