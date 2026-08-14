import 'package:flutter_test/flutter_test.dart';
import 'package:india_trading_app/services/watchlist_service.dart';

void main() {
  test('watchlist identity includes exchange and symbol', () {
    expect(WatchlistService.key('nse', 'abc'), 'NSE:ABC');
    expect(WatchlistService.key('bse', 'abc'), 'BSE:ABC');
    expect(
      WatchlistService.key('NSE', 'ABC'),
      isNot(WatchlistService.key('BSE', 'ABC')),
    );
  });
}
