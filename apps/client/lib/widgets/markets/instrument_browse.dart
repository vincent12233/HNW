import '../../models/stock_quote.dart';

const _foNeedles = ['F&O', 'FUTURE', 'OPTION', 'DERIVATIVE'];
const _commodityNeedles = ['COMMODITY', 'MCX', 'METAL', 'ENERGY'];
const _currencyNeedles = ['CURRENCY', 'FOREX', 'FX'];

bool _categoryContains(String category, List<String> needles) {
  return needles.any(category.contains);
}

/// Instruments the current client can list but cannot submit orders for.
bool isBrowseOnlyInstrument(StockQuote stock) {
  final category = stock.category?.trim().toUpperCase() ?? '';
  if (_categoryContains(category, _foNeedles)) return true;
  if (_categoryContains(category, _commodityNeedles)) return true;
  if (_categoryContains(category, _currencyNeedles)) return true;
  if (category.contains('ETF') || stock.symbol.toUpperCase().endsWith('BEES')) {
    return true;
  }
  return false;
}
