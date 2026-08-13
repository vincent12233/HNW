enum PendingOrderSide { buy, sell }

enum PendingOrderType { market, limit }

class PendingOrder {
  const PendingOrder({
    required this.id,
    required this.symbol,
    this.exchange = 'NSE',
    required this.side,
    required this.orderType,
    required this.quantity,
    required this.price,
    required this.createdAt,
  });

  final String id;
  final String symbol;
  final String exchange;
  final PendingOrderSide side;
  final PendingOrderType orderType;
  final int quantity;
  final double price;
  final DateTime createdAt;

  bool get isBuy => side == PendingOrderSide.buy;

  double get amount => quantity * price;

  factory PendingOrder.fromJson(Map<String, dynamic> json) {
    return PendingOrder(
      id: json['id'] as String,
      symbol: json['symbol'] as String,
      exchange:
          (json['exchange']?.toString().trim().toUpperCase().isNotEmpty ??
              false)
          ? json['exchange'].toString().trim().toUpperCase()
          : 'NSE',
      side: json['side'] == 'SELL'
          ? PendingOrderSide.sell
          : PendingOrderSide.buy,
      orderType: json['orderType'] == 'MARKET'
          ? PendingOrderType.market
          : PendingOrderType.limit,
      quantity: json['quantity'] as int,
      price: (json['price'] as num).toDouble(),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'symbol': symbol,
      'exchange': exchange,
      'side': isBuy ? 'BUY' : 'SELL',
      'orderType': orderType == PendingOrderType.market ? 'MARKET' : 'LIMIT',
      'quantity': quantity,
      'price': price,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
