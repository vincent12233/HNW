import 'package:flutter_test/flutter_test.dart';
import 'package:india_trading_app/models/market_history.dart';

void main() {
  test('parses OHLCV history and ignores invalid close rows', () {
    final series = MarketHistorySeries.fromJson({
      'symbol': 'SBIN',
      'interval': '1d',
      'data': [
        {
          'date': '2026-08-10',
          'open': 800,
          'high': 812,
          'low': 798,
          'close': 810,
          'volume': 1200000,
        },
        {
          'date': '2026-08-11',
          'open': '810',
          'high': '818',
          'low': '805',
          'close': '815',
          'volume': '1250000',
        },
        {
          'date': '2026-08-12',
          'open': 0,
          'high': 0,
          'low': 0,
          'close': 0,
          'volume': 0,
        },
      ],
    });

    expect(series.symbol, 'SBIN');
    expect(series.interval, '1d');
    expect(series.data, hasLength(2));
    expect(series.data.last.close, 815);
    expect(series.data.last.volume, 1250000);
  });
}
