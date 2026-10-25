import 'package:flutter_test/flutter_test.dart';
import 'package:india_trading_app/services/market_socket_service.dart';

void main() {
  test('quote freshness gate rejects duplicate and out-of-order updates', () {
    final gate = MarketQuoteFreshnessGate();
    final first = DateTime.utc(2026, 10, 25, 4, 0);

    expect(gate.accept('STOCK:NSE:RELIANCE', first), isTrue);
    expect(gate.accept('STOCK:NSE:RELIANCE', first), isFalse);
    expect(
      gate.accept(
        'STOCK:NSE:RELIANCE',
        first.subtract(const Duration(milliseconds: 1)),
      ),
      isFalse,
    );
    expect(
      gate.accept(
        'STOCK:NSE:RELIANCE',
        first.add(const Duration(milliseconds: 1)),
      ),
      isTrue,
    );
    expect(gate.accept('INDEX:NSE:NIFTY50', first), isTrue);
  });

  test('clearing the gate permits a fresh snapshot after session reset', () {
    final gate = MarketQuoteFreshnessGate();
    final timestamp = DateTime.utc(2026, 10, 25, 4, 0);

    expect(gate.accept('STOCK:NSE:TCS', timestamp), isTrue);
    expect(gate.accept('STOCK:NSE:TCS', timestamp), isFalse);
    gate.clear();
    expect(gate.accept('STOCK:NSE:TCS', timestamp), isTrue);
  });
}
