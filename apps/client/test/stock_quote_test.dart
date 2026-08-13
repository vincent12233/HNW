import 'package:flutter_test/flutter_test.dart';
import 'package:india_trading_app/models/stock_quote.dart';

void main() {
  test('preserves metadata when a live quote omits static fields', () {
    final initial = StockQuote.fromMarketDataJson({
      'symbol': 'RELIANCE',
      'exchange': 'BSE',
      'name': 'Reliance Industries',
      'price': 100,
      'change': 1.2,
      'volume': 1000,
      'updatedAt': '2026-08-12T00:00:00Z',
      'logoUrl': 'https://example.com/reliance.png',
      'category': 'Energy',
      'quoteFresh': true,
    });

    final live = StockQuote(
      initial.symbol,
      initial.name,
      101,
      2.2,
      1200,
      DateTime.parse('2026-08-12T00:00:01Z'),
      exchange: initial.exchange,
    );

    expect(live.name, 'Reliance Industries');
    expect(live.logoUrl, 'https://example.com/reliance.png');
    expect(live.category, 'Energy');
    expect(initial.exchange, 'BSE');
  });

  test('keeps backend quote freshness on market snapshots', () {
    final quote = StockQuote.fromMarketDataJson({
      'symbol': 'TCS',
      'name': 'Tata Consultancy Services',
      'price': 3200,
      'change': 0.5,
      'volume': 100,
      'updatedAt': '2026-08-12T00:00:00Z',
      'quoteFresh': false,
    });

    expect(quote.quoteFresh, isFalse);
  });

  test('does not present an old cached quote as fresh', () {
    final quote = StockQuote.fromMarketDataJson({
      'symbol': 'TCS',
      'name': 'Tata Consultancy Services',
      'price': 3200,
      'change': 0.5,
      'volume': 100,
      'updatedAt': DateTime.now()
          .subtract(const Duration(minutes: 10))
          .toUtc()
          .toIso8601String(),
      'quoteFresh': true,
    });

    expect(quote.quoteFresh, isFalse);
  });

  test('keeps a recent backend quote fresh', () {
    final quote = StockQuote.fromMarketDataJson({
      'symbol': 'TCS',
      'name': 'Tata Consultancy Services',
      'price': 3200,
      'change': 0.5,
      'volume': 100,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
      'quoteFresh': true,
    });

    expect(quote.quoteFresh, isTrue);
  });

  test('does not treat a missing quote timestamp as the current time', () {
    final quote = StockQuote.fromMarketDataJson({
      'symbol': 'INFY',
      'name': 'Infosys',
      'price': 1500,
      'change': 0.2,
      'volume': 50,
      'quoteFresh': false,
    });

    expect(quote.updatedAt.millisecondsSinceEpoch, 0);
    expect(quote.quoteFresh, isFalse);
  });

  test('parses bid ask and day session statistics', () {
    final quote = StockQuote.fromMarketDataJson({
      'symbol': 'SBIN',
      'name': 'State Bank of India',
      'price': '812.40',
      'change': 1.2,
      'volume': '1250000',
      'previousClose': '802.75',
      'open': '805.10',
      'high': '818.20',
      'low': '799.50',
      'bid': '812.35',
      'ask': '812.45',
      'updatedAt': '2026-08-12T09:30:00Z',
      'quoteFresh': true,
    });

    expect(quote.previousClose, 802.75);
    expect(quote.open, 805.10);
    expect(quote.high, 818.20);
    expect(quote.low, 799.50);
    expect(quote.bid, 812.35);
    expect(quote.ask, 812.45);
    expect(quote.volume, 1250000);
  });

  test('applies the complete realtime tick field mapping', () {
    final current = StockQuote.fromMarketDataJson({
      'symbol': 'SBIN',
      'exchange': 'NSE',
      'name': 'State Bank of India',
      'price': 800,
      'change': 0,
      'volume': 1000,
      'previousClose': 795,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
      'quoteFresh': true,
    });
    final updatedAt = DateTime.now().toUtc();

    final updated = StockQuote.applyRealtime(current, {
      'symbol': 'SBIN',
      'exchange': 'NSE',
      'price': 805,
      'change': 1.26,
      'volume': 1500,
      'previousClose': 795,
      'openPrice': 798,
      'highPrice': 807,
      'lowPrice': 796,
      'bidPrice': 804.95,
      'askPrice': 805.05,
      'updatedAt': updatedAt.toIso8601String(),
    });

    expect(updated, isNotNull);
    expect(updated!.price, 805);
    expect(updated.open, 798);
    expect(updated.high, 807);
    expect(updated.low, 796);
    expect(updated.bid, 804.95);
    expect(updated.ask, 805.05);
    expect(updated.volume, 1500);
  });

  test('does not apply a tick from another exchange', () {
    final current = StockQuote(
      'ABC',
      'ABC Limited',
      100,
      0,
      100,
      DateTime.now(),
      exchange: 'BSE',
    );

    expect(
      StockQuote.applyRealtime(current, {
        'symbol': 'ABC',
        'exchange': 'NSE',
        'price': 101,
      }),
      isNull,
    );
  });
}
