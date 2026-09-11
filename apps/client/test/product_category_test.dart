import 'package:flutter_test/flutter_test.dart';
import 'package:india_trading_app/utils/product_category.dart';

void main() {
  test('Portfolio admits only explicit product categories', () {
    for (final category in ['IT', 'BANKING', 'EQUITY', '', 'IPO INDUSTRIES']) {
      expect(portfolioCategory(category), isNull);
    }
    expect(portfolioCategory('INST'), 'Institutional');
    expect(portfolioCategory('LIMIT_UP'), 'Institutional');
    expect(portfolioCategory('otc'), 'OTC');
    expect(portfolioCategory('IPO'), 'IPO');
  });
}
