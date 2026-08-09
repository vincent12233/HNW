class TradingOrder {
  const TradingOrder({
    this.clientOrderId,
    this.status = 'FILLED',
    required this.symbol,
    required this.isBuy,
    required this.quantity,
    required this.price,
    required this.placedAt,
  });

  final String? clientOrderId;
  final String status;
  final String symbol;
  final bool isBuy;
  final int quantity;
  final double price;
  final DateTime placedAt;

  factory TradingOrder.fromJson(Map<String, dynamic> json) {
    return TradingOrder(
      clientOrderId: json['clientOrderId']?.toString(),
      status: json['status']?.toString() ?? 'FILLED',
      symbol: json['symbol'] as String,
      isBuy: json['isBuy'] as bool,
      quantity: json['quantity'] as int,
      price: (json['price'] as num).toDouble(),
      placedAt: DateTime.parse(json['placedAt'] as String),
    );
  }

  factory TradingOrder.fromApiJson(Map<String, dynamic> json) {
    final instrument = (json['instrument'] as Map?)?.cast<String, dynamic>();
    final trades = json['trades'];
    final firstTrade = trades is List && trades.isNotEmpty
        ? (trades.first as Map).cast<String, dynamic>()
        : null;

    return TradingOrder(
      clientOrderId: json['clientOrderId']?.toString(),
      status: json['status']?.toString() ?? 'FILLED',
      symbol: (instrument?['symbol'] ?? json['symbol'] ?? '').toString(),
      isBuy: json['side']?.toString() != 'SELL',
      quantity: _intValue(json['filledQuantity'] ?? json['quantity']),
      price: _doubleValue(
        firstTrade?['price'] ??
            json['averageFillPrice'] ??
            json['limitPrice'] ??
            '0',
      ),
      placedAt:
          DateTime.tryParse(
            (json['placedAt'] ?? json['createdAt'] ?? '').toString(),
          ) ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'symbol': symbol,
      'clientOrderId': clientOrderId,
      'status': status,
      'isBuy': isBuy,
      'quantity': quantity,
      'price': price,
      'placedAt': placedAt.toIso8601String(),
    };
  }

  double get amount => quantity * price;

  String get formattedTime {
    String twoDigits(int value) {
      return value.toString().padLeft(2, '0');
    }

    return '${twoDigits(placedAt.day)}/'
        '${twoDigits(placedAt.month)}/'
        '${placedAt.year} '
        '${twoDigits(placedAt.hour)}:'
        '${twoDigits(placedAt.minute)}';
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
