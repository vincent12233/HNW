List<TradingOrder> mergeConfirmedOrder(
  TradingOrder confirmed,
  List<TradingOrder> rows,
) {
  final containsConfirmed = rows.any(
    (row) =>
        (confirmed.orderId != null && row.orderId == confirmed.orderId) ||
        (confirmed.clientOrderId != null &&
            row.clientOrderId == confirmed.clientOrderId),
  );
  return containsConfirmed ? List.of(rows) : [confirmed, ...rows];
}

class TradingOrder {
  const TradingOrder({
    this.orderId,
    this.clientOrderId,
    this.status = 'FILLED',
    this.type = 'MARKET',
    this.timeInForce = 'DAY',
    this.limitPrice,
    this.averageFillPrice,
    this.rejectionReason,
    this.category = '',
    this.filledQuantity = 0,
    required this.symbol,
    this.exchange = 'NSE',
    required this.isBuy,
    required this.quantity,
    required this.price,
    required this.placedAt,
    this.updatedAt,
    this.completedAt,
    this.cancelledAt,
    this.fills = const <TradingFill>[],
  });

  final String? orderId;
  final String? clientOrderId;
  final String status;
  final String type;
  final String timeInForce;
  final double? limitPrice;
  final double? averageFillPrice;
  final String? rejectionReason;
  final String category;
  final int filledQuantity;
  final String symbol;
  final String exchange;
  final bool isBuy;
  final int quantity;
  final double price;
  final DateTime placedAt;
  final DateTime? updatedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final List<TradingFill> fills;

  int get remainingQuantity =>
      (quantity - filledQuantity).clamp(0, quantity).toInt();

  bool get isActive => status == 'OPEN' || status == 'PARTIALLY_FILLED';
  bool get isLimit => type == 'LIMIT';

  factory TradingOrder.fromConfirmation(
    dynamic response,
    String clientOrderId,
  ) {
    final row = response is Map ? response['order'] : null;
    if (row is! Map ||
        row['id'] is! String ||
        (row['id'] as String).isEmpty ||
        row['clientOrderId'] != clientOrderId ||
        !const [
          'PENDING',
          'OPEN',
          'PARTIALLY_FILLED',
          'FILLED',
          'CANCELLED',
          'REJECTED',
        ].contains(row['status']) ||
        !const ['BUY', 'SELL'].contains(row['side']) ||
        row['quantity'] is! num ||
        (row['quantity'] as num) <= 0) {
      throw const FormatException('Missing order confirmation');
    }
    return TradingOrder.fromApiJson(Map<String, dynamic>.from(row));
  }

  factory TradingOrder.fromJson(Map<String, dynamic> json) {
    return TradingOrder(
      orderId: json['orderId']?.toString(),
      clientOrderId: json['clientOrderId']?.toString(),
      status: json['status']?.toString() ?? 'FILLED',
      type: json['type']?.toString() ?? 'MARKET',
      timeInForce: json['timeInForce']?.toString() ?? 'DAY',
      limitPrice: _nullableDoubleValue(json['limitPrice']),
      averageFillPrice: _nullableDoubleValue(json['averageFillPrice']),
      rejectionReason: json['rejectionReason']?.toString(),
      category: json['category']?.toString() ?? '',
      filledQuantity: _intValue(json['filledQuantity']),
      symbol: json['symbol'] as String,
      exchange: (json['exchange'] ?? 'NSE').toString().toUpperCase(),
      isBuy: json['isBuy'] as bool,
      quantity: json['quantity'] as int,
      price: (json['price'] as num).toDouble(),
      placedAt: DateTime.parse(json['placedAt'] as String),
      updatedAt: _nullableDateTime(json['updatedAt']),
      completedAt: _nullableDateTime(json['completedAt']),
      cancelledAt: _nullableDateTime(json['cancelledAt']),
      fills: _fillsFromJson(json['fills'] ?? json['trades']),
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
    final clientOrderId = json['clientOrderId']?.toString() ?? '';
    final sourceCategory = clientOrderId.startsWith('OTC-')
        ? 'OTC'
        : clientOrderId.startsWith('IPO-')
        ? 'IPO'
        : (instrument?['category'] ?? json['category'] ?? '').toString();

    return TradingOrder(
      orderId: json['id']?.toString() ?? json['orderId']?.toString(),
      clientOrderId: clientOrderId.isEmpty ? null : clientOrderId,
      status: json['status']?.toString() ?? 'FILLED',
      type: json['type']?.toString() ?? 'MARKET',
      timeInForce: json['timeInForce']?.toString() ?? 'DAY',
      limitPrice: limitPrice,
      averageFillPrice: averageFillPrice,
      rejectionReason: json['rejectionReason']?.toString(),
      category: sourceCategory,
      filledQuantity: filledQuantity,
      symbol: (instrument?['symbol'] ?? json['symbol'] ?? '').toString(),
      exchange: (instrument?['exchange'] ?? json['exchange'] ?? 'NSE')
          .toString()
          .toUpperCase(),
      isBuy: json['side']?.toString() != 'SELL',
      quantity: quantity > 0 ? quantity : filledQuantity,
      price: firstTradePrice ?? averageFillPrice ?? limitPrice ?? 0,
      placedAt:
          DateTime.tryParse(
            (json['placedAt'] ?? json['createdAt'] ?? '').toString(),
          ) ??
          DateTime.now(),
      updatedAt: _nullableDateTime(json['updatedAt']),
      completedAt: _nullableDateTime(json['completedAt']),
      cancelledAt: _nullableDateTime(json['cancelledAt']),
      fills: _fillsFromJson(trades),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'orderId': orderId,
      'symbol': symbol,
      'exchange': exchange,
      'clientOrderId': clientOrderId,
      'status': status,
      'type': type,
      'timeInForce': timeInForce,
      'limitPrice': limitPrice,
      'averageFillPrice': averageFillPrice,
      'rejectionReason': rejectionReason,
      'category': category,
      'filledQuantity': filledQuantity,
      'isBuy': isBuy,
      'quantity': quantity,
      'price': price,
      'placedAt': placedAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'cancelledAt': cancelledAt?.toIso8601String(),
      'fills': fills.map((fill) => fill.toJson()).toList(),
    };
  }

  TradingOrder withClientOrderId(String value) {
    return TradingOrder(
      orderId: orderId,
      clientOrderId: value,
      status: status,
      type: type,
      timeInForce: timeInForce,
      limitPrice: limitPrice,
      averageFillPrice: averageFillPrice,
      rejectionReason: rejectionReason,
      category: category,
      filledQuantity: filledQuantity,
      symbol: symbol,
      exchange: exchange,
      isBuy: isBuy,
      quantity: quantity,
      price: price,
      placedAt: placedAt,
      updatedAt: updatedAt,
      completedAt: completedAt,
      cancelledAt: cancelledAt,
      fills: fills,
    );
  }

  /// Logical order fingerprint used to decide when a new clientOrderId is required.
  String submissionFingerprint() {
    final limit = limitPrice?.toStringAsFixed(4) ?? '';
    return [
      exchange.toUpperCase(),
      symbol.toUpperCase(),
      isBuy ? 'BUY' : 'SELL',
      type.toUpperCase(),
      timeInForce.toUpperCase(),
      quantity.toString(),
      limit,
    ].join('|');
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

class TradingFill {
  const TradingFill({
    required this.executionId,
    required this.quantity,
    required this.price,
    required this.grossAmount,
    required this.fees,
    required this.netAmount,
    required this.executedAt,
  });

  final String executionId;
  final int quantity;
  final double price;
  final double grossAmount;
  final double fees;
  final double netAmount;
  final DateTime executedAt;

  factory TradingFill.fromJson(Map<String, dynamic> json) {
    return TradingFill(
      executionId: json['executionId']?.toString() ?? '',
      quantity: _intValue(json['quantity']),
      price: _doubleValue(json['price']),
      grossAmount: _doubleValue(json['grossAmount']),
      fees: _doubleValue(json['fees']),
      netAmount: _doubleValue(json['netAmount']),
      executedAt:
          _nullableDateTime(json['executedAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'executionId': executionId,
    'quantity': quantity,
    'price': price,
    'grossAmount': grossAmount,
    'fees': fees,
    'netAmount': netAmount,
    'executedAt': executedAt.toIso8601String(),
  };
}

List<TradingFill> _fillsFromJson(dynamic value) {
  if (value is! List) return const <TradingFill>[];
  return value
      .whereType<Map>()
      .map((row) => TradingFill.fromJson(Map<String, dynamic>.from(row)))
      .where(
        (fill) =>
            fill.quantity > 0 &&
            fill.price > 0 &&
            fill.executedAt.millisecondsSinceEpoch > 0,
      )
      .toList();
}

DateTime? _nullableDateTime(dynamic value) =>
    DateTime.tryParse(value?.toString() ?? '');

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
