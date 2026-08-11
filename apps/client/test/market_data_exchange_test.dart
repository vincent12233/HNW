import 'package:flutter_test/flutter_test.dart';
import 'package:india_trading_app/services/market_data_service.dart';

void main() {
  test('accepts realtime quote when preferred exchange is unknown', () {
    expect(
      MarketDataService.acceptsRealtimeQuote({
        'symbol': 'ABC',
        'exchange': 'BSE',
      }),
      isTrue,
    );
  });
}
