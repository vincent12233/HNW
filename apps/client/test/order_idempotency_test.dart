import 'package:flutter_test/flutter_test.dart';
import 'package:india_trading_app/models/trading_order.dart';
import 'package:india_trading_app/services/trading_service.dart';

void main() {
  tearDown(() {
    TradingService.clearInFlightSubmissions();
    TradingService.clearLastPlacedOrder();
  });

  TradingOrder draft({
    String? clientOrderId,
    int quantity = 1,
    String symbol = 'RELIANCE',
  }) {
    return TradingOrder(
      clientOrderId: clientOrderId,
      symbol: symbol,
      exchange: 'NSE',
      isBuy: true,
      quantity: quantity,
      price: 100,
      placedAt: DateTime.parse('2026-09-18T10:00:00.000Z'),
      type: 'MARKET',
      timeInForce: 'DAY',
    );
  }

  test('normal submit allocates one clientOrderId for a logical order', () {
    final first = TradingService.createClientOrderId(
      exchange: 'NSE',
      symbol: 'RELIANCE',
    );
    final second = TradingService.createClientOrderId(
      exchange: 'NSE',
      symbol: 'RELIANCE',
    );
    expect(first, isNot(equals(second)));
    expect(first, startsWith('APP-'));
    expect(first, contains('NSE-RELIANCE'));
  });

  test('retry and timeout retry reuse the same provided clientOrderId', () {
    const logicalId = 'APP-retry-NSE-RELIANCE';
    final first = draft(clientOrderId: logicalId);
    final retry = draft(clientOrderId: logicalId);
    final timeoutRetry = draft(clientOrderId: logicalId);

    expect(first.clientOrderId, logicalId);
    expect(retry.clientOrderId, logicalId);
    expect(timeoutRetry.clientOrderId, logicalId);
  });

  test('double tap coalesces to one in-flight submission', () async {
    final guard = ClientOrderSubmissionGuard();
    var submitCount = 0;

    Future<TradingOrder> submit() {
      return guard.run('APP-double-tap-NSE-RELIANCE', () async {
        submitCount += 1;
        await Future<void>.delayed(const Duration(milliseconds: 30));
        return draft(clientOrderId: 'APP-double-tap-NSE-RELIANCE');
      });
    }

    final results = await Future.wait([submit(), submit()]);
    expect(submitCount, 1);
    expect(results[0].clientOrderId, results[1].clientOrderId);
    expect(guard.inFlightCount, 0);
  });

  test('new logical order uses a different fingerprint and id', () {
    final buyOne = draft(quantity: 1);
    final buyTwo = draft(quantity: 2);
    expect(
      buyOne.submissionFingerprint(),
      isNot(buyTwo.submissionFingerprint()),
    );

    final withId = buyOne.withClientOrderId('APP-1');
    final changed = buyTwo.withClientOrderId('APP-2');
    expect(withId.clientOrderId, 'APP-1');
    expect(changed.clientOrderId, 'APP-2');
  });
}
