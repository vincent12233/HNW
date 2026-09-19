class MarketIndexRef {
  const MarketIndexRef({
    required this.label,
    required this.symbol,
    required this.exchange,
    required this.venue,
  });

  final String label;
  final String symbol;
  final String exchange;
  final String venue;

  /// Full OHLC history is only served for NSE/BSE by the current client API.
  bool get supportsHistoryChart => exchange == 'NSE' || exchange == 'BSE';

  static const all = <MarketIndexRef>[
    MarketIndexRef(
      label: 'NIFTY 50',
      symbol: 'NIFTY50',
      exchange: 'NSE',
      venue: 'NSE',
    ),
    MarketIndexRef(
      label: 'SENSEX',
      symbol: 'SENSEX',
      exchange: 'BSE',
      venue: 'BSE',
    ),
    MarketIndexRef(
      label: 'BANK NIFTY',
      symbol: 'BANKNIFTY',
      exchange: 'NSE',
      venue: 'NSE',
    ),
    MarketIndexRef(
      label: 'INDIA VIX',
      symbol: 'INDIAVIX',
      exchange: 'NSE',
      venue: 'NSE',
    ),
    MarketIndexRef(
      label: 'DOW JONES',
      symbol: 'DJI',
      exchange: 'NYSE',
      venue: 'GLOBAL',
    ),
    MarketIndexRef(
      label: 'NASDAQ',
      symbol: 'IXIC',
      exchange: 'NASDAQ',
      venue: 'GLOBAL',
    ),
    MarketIndexRef(
      label: 'S&P 500',
      symbol: 'GSPC',
      exchange: 'NYSE',
      venue: 'GLOBAL',
    ),
    MarketIndexRef(
      label: 'FTSE 100',
      symbol: 'FTSE',
      exchange: 'LSE',
      venue: 'GLOBAL',
    ),
  ];

  static MarketIndexRef? byLabel(String label) {
    final needle = label.trim().toUpperCase();
    for (final item in all) {
      if (item.label.toUpperCase() == needle) return item;
    }
    return null;
  }
}

class MarketIndexQuote {
  const MarketIndexQuote({
    required this.ref,
    required this.price,
    required this.changePercent,
    this.history = const [],
  });

  final MarketIndexRef ref;
  final double price;
  final double changePercent;
  final List<double> history;

  bool get available => price > 0 && price.isFinite && changePercent.isFinite;
}
