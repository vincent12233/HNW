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
  }) {
    final normalizedSymbol = symbol.trim().toUpperCase();
    final previous = _metadata[normalizedSymbol];
    final resolvedName = name.isNotEmpty ? name : previous?.name ?? '';
    final resolvedLogoUrl = logoUrl ?? previous?.logoUrl;
    final resolvedCategory = category ?? previous?.category;

    if (normalizedSymbol.isNotEmpty) {
      _metadata[normalizedSymbol] = _StockMetadata(
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

  factory StockQuote.fromMarketDataJson(Map<String, dynamic> json) {
    final price = _doubleValue(json['price']) ?? 0;
    final rawChange = _doubleValue(json['change']) ??
        _doubleValue(json['changePercent']) ??
        0;
    final previousClose = _doubleValue(json['previousClose']) ?? 0;
    final change = rawChange != 0 || previousClose <= 0
        ? rawChange
        : ((price - previousClose) / previousClose) * 100;
    final updatedAt = DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

    return StockQuote(
      json['symbol']?.toString() ?? '',
      json['name']?.toString() ?? '',
      price,
      change,
      _intValue(json['volume']),
      updatedAt,
      logoUrl: json['logoUrl']?.toString(),
      category: json['category']?.toString(),
      quoteFresh: json['quoteFresh'] == true,
      previousClose: previousClose > 0 ? previousClose : null,
      open: _positiveDoubleValue(json['open']),
      high: _positiveDoubleValue(json['high']),
      low: _positiveDoubleValue(json['low']),
      bid: _positiveDoubleValue(json['bid']),
      ask: _positiveDoubleValue(json['ask']),
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
