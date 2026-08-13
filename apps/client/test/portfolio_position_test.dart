import 'package:flutter_test/flutter_test.dart';
import 'package:india_trading_app/models/portfolio_position.dart';

void main() {
  test('parses exchange and backend available quantity', () {
    final position = PortfolioPosition.fromApiJson({
      'exchange': 'BSE',
      'symbol': 'RELIANCE',
      'name': 'Reliance Industries',
      'quantity': 12,
      'frozenQuantity': 5,
      'availableQuantity': 7,
      'averagePrice': '2800.50',
    });

    expect(position.exchange, 'BSE');
    expect(position.quantity, 12);
    expect(position.availableQuantity, 7);
  });

  test('uses total quantity for older cached positions', () {
    final position = PortfolioPosition.fromJson({
      'symbol': 'TCS',
      'name': 'TCS',
      'category': 'IT',
      'quantity': 4,
      'averageCost': 3500,
    });

    expect(position.exchange, 'NSE');
    expect(position.availableQuantity, 4);
  });
}
