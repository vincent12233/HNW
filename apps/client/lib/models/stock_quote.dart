class StockQuote {
  const StockQuote(
    this.symbol,
    this.name,
    this.price,
    this.change,
    this.volume,
    this.updatedAt,
    {this.logoUrl, this.category},
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
    return StockQuote(
      json['symbol']?.toString() ?? '',
      json['name']?.toString() ?? '',
      (json['price'] as num?)?.toDouble() ??
          double.tryParse(json['price']?.toString() ?? '') ??
          0,
      (json['change'] as num?)?.toDouble() ??
          double.tryParse(json['change']?.toString() ?? '') ??
          0,
      (json['volume'] as num?)?.toInt() ??
          int.tryParse(json['volume']?.toString() ?? '') ??
          0,
      DateTime.tryParse(json['updatedAt']?.toString() ?? '') ?? DateTime.now(),
      logoUrl: json['logoUrl']?.toString(),
      category: json['category']?.toString(),
    );
  }
}
