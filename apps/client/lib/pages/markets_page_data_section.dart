part of 'markets_page.dart';

extension _MarketsPageDataSection on _MarketsPageState {
  String _instrumentKey(StockQuote stock) =>
      '${stock.exchange}:${stock.symbol}';

  Future<void> _loadYearRanges({bool force = false}) async {
    if (_yearRangesLoading || (!force && _yearRanges.isNotEmpty)) return;
    if (mounted) _updateState(() => _yearRangesLoading = true);
    final candidates = widget.stocks.where((stock) => stock.price > 0).toList()
      ..sort((left, right) => right.volume.compareTo(left.volume));
    final results = await Future.wait(
      candidates.take(20).map((stock) async {
        try {
          final history = await _marketDataService.fetchHistory(
            symbol: stock.symbol,
            exchange: stock.exchange,
            range: '1Y',
          );
          final prices = history.data
              .map((point) => point.close)
              .where((price) => price > 0)
              .toList();
          if (prices.length < 2) return (_instrumentKey(stock), null);
          prices.sort();
          return (_instrumentKey(stock), (prices.first, prices.last));
        } catch (_) {
          return (_instrumentKey(stock), null);
        }
      }),
    );
    if (!mounted) return;
    _updateState(() {
      if (force) _yearRanges.clear();
      for (final result in results) {
        if (result.$2 != null) _yearRanges[result.$1] = result.$2!;
      }
      _yearRangesLoading = false;
    });
  }


}