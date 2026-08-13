import 'package:flutter_test/flutter_test.dart';
import 'package:india_trading_app/models/market_history.dart';

void main() {
  test('parses OHLCV history and ignores invalid close rows', () {
    final series = MarketHistorySeries.fromJson({
      'symbol': 'SBIN',
      'exchange': 'NSE',
      'range': '1M',
      'timezone': 'Asia/Kolkata',
      'interval': '1d',
      'events': [
        {
          'date': '2026-08-10T00:00:00Z',
          'type': 'DIVIDEND',
          'value': 5.5,
          'label': 'Dividend 5.50',
        },
        {'date': 'invalid', 'type': 'SPLIT', 'value': 2, 'label': 'Split 2:1'},
      ],
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
        {
          'date': '2026-08-13',
          'open': 810,
          'high': 805,
          'low': 800,
          'close': 812,
          'volume': 100,
        },
      ],
    });

    expect(series.symbol, 'SBIN');
    expect(series.interval, '1d');
    expect(series.exchange, 'NSE');
    expect(series.range, '1M');
    expect(series.events, hasLength(1));
    expect(series.events.first.type, 'DIVIDEND');
    expect(series.events.first.value, 5.5);
    expect(series.timezone, 'Asia/Kolkata');
    expect(series.data, hasLength(2));
    expect(series.data.last.close, 815);
    expect(series.data.last.volume, 1250000);
    expect(series.delayed, isFalse);
  });

  test('marks a cached real history response as delayed', () {
    final series = MarketHistorySeries.fromJson({
      'symbol': 'SBIN',
      'exchange': 'NSE',
      'range': '1D',
      'timezone': 'Asia/Kolkata',
      'interval': '5m',
      'data': [
        {
          'date': '2026-08-12T09:15:00Z',
          'open': 800,
          'high': 812,
          'low': 798,
          'close': 810,
          'volume': 1200000,
        },
      ],
    }, delayed: true);

    expect(series.delayed, isTrue);
    expect(series.data, hasLength(1));
  });
}
