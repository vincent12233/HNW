class StockQuote {
  factory StockQuote(
    String symbol,
    String name,
    double price,
    double change,
    int volume,
    DateTime updatedAt, {
    String? logoUrl,
    String? category,
    bool quoteFresh = true,
    double? previousClose,
    double? open,
    double? high,
    double? low,
    double? bid,
    double? ask,
    String exchange = 'NSE',
  }) {
    final normalizedSymbol = symbol.trim().toUpperCase();
    final normalizedExchange = exchange.trim().toUpperCase() == 'BSE'
        ? 'BSE'
        : 'NSE';
    final metadataKey = '$normalizedExchange:$normalizedSymbol';
    final previous = _metadata[metadataKey];
    final resolvedName = name.isNotEmpty ? name : previous?.name ?? '';
    final resolvedLogoUrl = logoUrl ?? previous?.logoUrl;
    final resolvedCategory = category ?? previous?.category;

    if (normalizedSymbol.isNotEmpty) {
      _metadata[metadataKey] = _StockMetadata(
        resolvedName,
        resolvedLogoUrl,
        resolvedCategory,
      );
    }

    return StockQuote._(
      normalizedSymbol,
      resolvedName,
      price,
      change,
      volume,
      updatedAt,
      logoUrl: resolvedLogoUrl,
      category: resolvedCategory,
      quoteFresh: quoteFresh,
      previousClose: previousClose,
      open: open,
      high: high,
      low: low,
      bid: bid,
      ask: ask,
      exchange: normalizedExchange,
    );
  }

  const StockQuote._(
    this.symbol,
    this.name,
    this.price,
    this.change,
    this.volume,
    this.updatedAt, {
    this.logoUrl,
    this.category,
    this.quoteFresh = true,
    this.previousClose,
    this.open,
    this.high,
    this.low,
    this.bid,
    this.ask,
    this.exchange = 'NSE',
  });

  static final Map<String, _StockMetadata> _metadata =
      <String, _StockMetadata>{};

  final String symbol;
  final String name;
  final double price;
  final double change;
  final int volume;
  final DateTime updatedAt;
  final String? logoUrl;
  final String? category;
  final bool quoteFresh;
  final double? previousClose;
  final double? open;
  final double? high;
  final double? low;
  final double? bid;
  final double? ask;
  final String exchange;

  factory StockQuote.fromMarketDataJson(Map<String, dynamic> json) {
    final price = _doubleValue(json['price']) ?? 0;
    final rawChange =
        _doubleValue(json['change']) ??
        _doubleValue(json['changePercent']) ??
        0;
    final previousClose = _doubleValue(json['previousClose']) ?? 0;
    final change = rawChange != 0 || previousClose <= 0
        ? rawChange
        : ((price - previousClose) / previousClose) * 100;
    final updatedAt =
        DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    final age = DateTime.now().difference(updatedAt);
    final quoteFresh =
        json['quoteFresh'] == true && age <= const Duration(minutes: 2);

    return StockQuote(
      json['symbol']?.toString() ?? '',
      json['name']?.toString() ?? '',
      price,
      change,
      _intValue(json['volume']),
      updatedAt,
      logoUrl: json['logoUrl']?.toString(),
      category: json['category']?.toString(),
      quoteFresh: quoteFresh,
      previousClose: previousClose > 0 ? previousClose : null,
      open: _positiveDoubleValue(json['open']),
      high: _positiveDoubleValue(json['high']),
      low: _positiveDoubleValue(json['low']),
      bid: _positiveDoubleValue(json['bid']),
      ask: _positiveDoubleValue(json['ask']),
      exchange: json['exchange']?.toString() ?? 'NSE',
    );
  }

  static StockQuote? applyRealtime(
    StockQuote current,
    Map<String, dynamic> json,
  ) {
    final symbol = json['symbol']?.toString().trim().toUpperCase();
    final exchange = json['exchange']?.toString().trim().toUpperCase();
    if (symbol != current.symbol ||
        (exchange != null &&
            exchange.isNotEmpty &&
            exchange != current.exchange)) {
      return null;
    }

    final price = _positiveDoubleValue(json['price']);
    if (price == null) return null;
    final updatedAt =
        DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
        current.updatedAt;
    final change =
        _doubleValue(json['change']) ??
        (current.previousClose != null && current.previousClose! > 0
            ? ((price - current.previousClose!) / current.previousClose!) * 100
            : current.change);

    return StockQuote(
      current.symbol,
      current.name,
      price,
      change,
      _intValue(json['volume']) > 0
          ? _intValue(json['volume'])
          : current.volume,
      updatedAt,
      logoUrl: current.logoUrl,
      category: current.category,
      quoteFresh:
          DateTime.now().difference(updatedAt) <= const Duration(minutes: 2),
      previousClose: _realtimePrice(
        json,
        'previousClose',
        'previousClose',
        current.previousClose,
      ),
      open: _realtimePrice(json, 'openPrice', 'open', current.open),
      high: _realtimePrice(json, 'highPrice', 'high', current.high),
      low: _realtimePrice(json, 'lowPrice', 'low', current.low),
      bid: _realtimePrice(json, 'bidPrice', 'bid', current.bid),
      ask: _realtimePrice(json, 'askPrice', 'ask', current.ask),
      exchange: current.exchange,
    );
  }
}

class _StockMetadata {
  const _StockMetadata(this.name, this.logoUrl, this.category);

  final String name;
  final String? logoUrl;
  final String? category;
}

double? _doubleValue(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}

int _intValue(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double? _positiveDoubleValue(dynamic value) {
  final parsed = _doubleValue(value);
  return parsed != null && parsed > 0 ? parsed : null;
}

double? _realtimePrice(
  Map<String, dynamic> json,
  String primaryKey,
  String fallbackKey,
  double? current,
) =>
    _positiveDoubleValue(json[primaryKey]) ??
    _positiveDoubleValue(json[fallbackKey]) ??
    current;
