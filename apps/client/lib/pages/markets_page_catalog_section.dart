part of 'markets_page.dart';

extension _MarketsCatalogSection on _MarketsPageState {
  Widget _etfList() {
    final etfs = _filteredStocks.where((stock) {
      final category = stock.category?.toUpperCase() ?? '';
      return category.contains('ETF') || stock.symbol.endsWith('BEES');
    }).toList();
    return _stockList(
      etfs,
      emptyTitle: 'ETF data unavailable',
      emptySubtitle:
          'ETF quotes will appear when enabled by the market catalog.',
      allowPagination: query.trim().isNotEmpty,
      browseOnlyLabel: 'ETFs',
    );
  }

  Widget _categoryList(
    List<String> keywords, {
    required String emptyTitle,
    required String emptySubtitle,
    String? browseOnlyLabel,
  }) {
    final instruments = _filteredStocks.where((stock) {
      final category = stock.category?.trim().toUpperCase() ?? '';
      return keywords.any(category.contains);
    }).toList();
    return _stockList(
      instruments,
      emptyTitle: emptyTitle,
      emptySubtitle: emptySubtitle,
      allowPagination: query.trim().isNotEmpty,
      browseOnlyLabel: browseOnlyLabel,
    );
  }
}