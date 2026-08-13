import 'package:flutter_test/flutter_test.dart';
import 'package:india_trading_app/utils/number_formatters.dart';

void main() {
  test('formats signed rupee changes in trading-app style', () {
    expect(formatSignedPrice(12.5), '+₹12.50');
    expect(formatSignedPrice(-12.5), '-₹12.50');
    expect(formatSignedPrice(0), '+₹0.00');
  });
}
