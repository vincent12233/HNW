class TradingOrder {
  const TradingOrder({
    this.orderId,
    this.clientOrderId,
    this.status = 'FILLED',
    this.type = 'MARKET',
    this.timeInForce = 'DAY',
    this.limitPrice,
    this.filledQuantity = 0,
    required this.symbol,
    required this.isBuy,
    required this.quantity,
    required this.price,
    required this.placedAt,
  });

  final String? orderId;
  final String? clientOrderId;
  final String status;
  final String type;
  final String timeInForce;
  final double? limitPrice;
  final int filledQuantity;
  final String symbol;
  final bool isBuy;
  final int quantity;
  final double price;
  final DateTime placedAt;

  int get remainingQuantity =>
      (quantity - filledQuantity).clamp(0, quantity).toInt();

  bool get isActive => status == 'OPEN' || status == 'PARTIALLY_FILLED';
  bool get isLimit => type == 'LIMIT';

  factory TradingOrder.fromJson(Map<String, dynamic> json) {
    return TradingOrder(
      orderId: json['orderId']?.toString(),
      clientOrderId: json['clientOrderId']?.toString(),
      status: json['status']?.toString() ?? 'FILLED',
      type: json['type']?.toString() ?? 'MARKET',
      timeInForce: json['timeInForce']?.toString() ?? 'DAY',
      limitPrice: _nullableDoubleValue(json['limitPrice']),
      filledQuantity: _intValue(json['filledQuantity']),
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
    final quantity = _intValue(json['quantity']);
    final filledQuantity = _intValue(json['filledQuantity']);
    final limitPrice = _nullableDoubleValue(json['limitPrice']);
    final averageFillPrice = _nullableDoubleValue(json['averageFillPrice']);
    final firstTradePrice = _nullableDoubleValue(firstTrade?['price']);

    return TradingOrder(
      orderId: json['id']?.toString() ?? json['orderId']?.toString(),
      clientOrderId: json['clientOrderId']?.toString(),
      status: json['status']?.toString() ?? 'FILLED',
      type: json['type']?.toString() ?? 'MARKET',
      timeInForce: json['timeInForce']?.toString() ?? 'DAY',
      limitPrice: limitPrice,
      filledQuantity: filledQuantity,
      symbol: (instrument?['symbol'] ?? json['symbol'] ?? '').toString(),
      isBuy: json['side']?.toString() != 'SELL',
      quantity: quantity > 0 ? quantity : filledQuantity,
      price: firstTradePrice ?? averageFillPrice ?? limitPrice ?? 0,
      placedAt:
          DateTime.tryParse(
            (json['placedAt'] ?? json['createdAt'] ?? '').toString(),
          ) ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'orderId': orderId,
      'symbol': symbol,
      'clientOrderId': clientOrderId,
      'status': status,
      'type': type,
      'timeInForce': timeInForce,
      'limitPrice': limitPrice,
      'filledQuantity': filledQuantity,
      'isBuy': isBuy,
      'quantity': quantity,
      'price': price,
      'placedAt': placedAt.toIso8601String(),
    };
  }

  double get amount => quantity * (limitPrice ?? price);

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
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _doubleValue(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

double? _nullableDoubleValue(dynamic value) {
  if (value == null) return null;
  final parsed = _doubleValue(value);
  return parsed > 0 ? parsed : null;
}
