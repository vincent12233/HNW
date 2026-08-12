import 'package:flutter_test/flutter_test.dart';
import 'package:india_trading_app/models/stock_quote.dart';

void main() {
  test('preserves metadata when a live quote omits static fields', () {
    final initial = StockQuote.fromMarketDataJson({
      'symbol': 'RELIANCE',
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
    );

    expect(live.name, 'Reliance Industries');
    expect(live.logoUrl, 'https://example.com/reliance.png');
    expect(live.category, 'Energy');
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
}
