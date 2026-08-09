class StockQuote {
  const StockQuote(
    this.symbol,
    this.name,
    this.price,
    this.change,
    this.volume,
    this.updatedAt,
    {this.logoUrl, this.category}
  );

  final String symbol;
  final String name;
  final double price;
  final double change;
  final int volume;
  final DateTime updatedAt;
  final String? logoUrl;
  final String? category;

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

    return StockQuote(
      json['symbol']?.toString() ?? '',
      json['name']?.toString() ?? '',
      price,
      change,
      (json['volume'] as num?)?.toInt() ??
          int.tryParse(json['volume']?.toString() ?? '') ??
          0,
      DateTime.tryParse(json['updatedAt']?.toString() ?? '') ?? DateTime.now(),
      logoUrl: json['logoUrl']?.toString(),
      category: json['category']?.toString(),
    );
  }
}
