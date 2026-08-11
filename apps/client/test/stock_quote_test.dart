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
}
