class PortfolioPosition {
  const PortfolioPosition({
    required this.symbol,
    required this.name,
    required this.category,
    this.logoUrl,
    required this.quantity,
    required this.averageCost,
  });

  final String symbol;
  final String name;
  final String category;
  final String? logoUrl;
  final int quantity;
  final double averageCost;

  factory PortfolioPosition.fromJson(Map<String, dynamic> json) {
    return PortfolioPosition(
      symbol: json['symbol'] as String,
      name: (json['name'] ?? json['symbol'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
      logoUrl: json['logoUrl']?.toString(),
      quantity: json['quantity'] as int,
      averageCost: (json['averageCost'] as num).toDouble(),
    );
  }

  factory PortfolioPosition.fromApiJson(Map<String, dynamic> json) {
    final instrument = (json['instrument'] as Map?)?.cast<String, dynamic>();

    return PortfolioPosition(
      symbol: (instrument?['symbol'] ?? json['symbol'] ?? '').toString(),
      name: (instrument?['name'] ?? json['name'] ?? '').toString(),
      category: (instrument?['category'] ?? json['category'] ?? '').toString(),
      logoUrl: (instrument?['logoUrl'] ?? json['logoUrl'])?.toString(),
      quantity: _intValue(json['quantity']),
      averageCost: _doubleValue(json['averagePrice'] ?? json['averageCost']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'symbol': symbol,
      'name': name,
      'category': category,
      'logoUrl': logoUrl,
      'quantity': quantity,
      'averageCost': averageCost,
    };
  }

  double marketValue(double currentPrice) {
    return quantity * currentPrice;
  }

  double unrealizedProfitLoss(double currentPrice) {
    return (currentPrice - averageCost) * quantity;
  }

  double returnPercent(double currentPrice) {
    if (averageCost == 0) {
      return 0;
    }

    return ((currentPrice - averageCost) / averageCost) * 100;
  }
}

int _intValue(dynamic value) {
  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _doubleValue(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }

  return double.tryParse(value?.toString() ?? '') ?? 0;
}
