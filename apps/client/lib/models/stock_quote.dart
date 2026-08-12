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

  factory StockQuote.fromMarketDataJson(Map<String, dynamic> json) {
    final price = (json['price'] as num?)?.toDouble() ??
        double.tryParse(json['price']?.toString() ?? '') ??
        0;
    final rawChange = (json['change'] as num?)?.toDouble() ??
        double.tryParse(json['change']?.toString() ?? '') ??
        (json['changePercent'] as num?)?.toDouble() ??
        double.tryParse(json['changePercent']?.toString() ?? '') ??
        0;
    final previousClose = (json['previousClose'] as num?)?.toDouble() ??
        double.tryParse(json['previousClose']?.toString() ?? '') ??
        0;
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
      (json['volume'] as num?)?.toInt() ??
          int.tryParse(json['volume']?.toString() ?? '') ??
          0,
      updatedAt,
      logoUrl: json['logoUrl']?.toString(),
      category: json['category']?.toString(),
      quoteFresh: json['quoteFresh'] == true,
    );
  }
}

class _StockMetadata {
  const _StockMetadata(this.name, this.logoUrl, this.category);

  final String name;
  final String? logoUrl;
  final String? category;
}
