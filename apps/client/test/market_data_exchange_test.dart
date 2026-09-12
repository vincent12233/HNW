import 'package:flutter_test/flutter_test.dart';
import 'package:india_trading_app/services/market_data_service.dart';
import 'package:india_trading_app/services/local_data_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('cached home snapshot preserves listings on both exchanges', () async {
    SharedPreferences.setMockInitialValues({});
    await LocalDataCache.saveJson(LocalDataCache.marketSnapshot, [
      {'symbol': 'ABC', 'exchange': 'NSE', 'price': 100},
      {'symbol': 'ABC', 'exchange': 'BSE', 'price': 101},
      {'symbol': 'ABC', 'exchange': 'NSE', 'price': 100},
    ]);
    final stocks = await MarketDataService().fetchHomeBootstrap();
    expect(stocks.length, 2);
    expect(
      stocks.map((stock) => '${stock.exchange}:${stock.symbol}'),
      containsAll(['NSE:ABC', 'BSE:ABC']),
    );
    expect(stocks.firstWhere((stock) => stock.exchange == 'BSE').price, 101);
  });

  test('cached home snapshot excludes non-Indian exchanges', () async {
    await LocalDataCache.saveJson(LocalDataCache.marketSnapshot, [
      {'symbol': 'TCS', 'exchange': 'NSE', 'price': 100},
      {'symbol': 'RELIANCE', 'exchange': 'BSE', 'price': 101},
      {'symbol': 'AAPL', 'exchange': 'NASDAQ', 'price': 200},
      {'symbol': 'IBM', 'exchange': 'NYSE', 'price': 150},
    ]);

    final stocks = await MarketDataService().fetchHomeBootstrap();

    expect(stocks.map((stock) => '${stock.exchange}:${stock.symbol}'), [
      'NSE:TCS',
      'BSE:RELIANCE',
    ]);
  });
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
