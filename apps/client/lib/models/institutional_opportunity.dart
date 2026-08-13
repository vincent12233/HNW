class InstitutionalStock {
  const InstitutionalStock({
    required this.id,
    required this.symbol,
    required this.companyName,
    required this.price,
    this.minimumQuantity,
    required this.status,
    this.exchange = 'NSE',
    this.direction = 'UP',
    this.referencePrice,
    this.expectedReturn,
    this.reason,
  });

  final String id;
  final String symbol;
  final String companyName;
  final double price;
  @Deprecated('Quantity limits are not used for Inst. or OTC orders')
  final int? minimumQuantity;
  final String status;
  final String exchange;
  final String direction;
  final double? referencePrice;
  final double? expectedReturn;
  final String? reason;

  factory InstitutionalStock.fromOtcJson(Map<String, dynamic> json) {
    final instrument =
        (json['instrument'] as Map?)?.cast<String, dynamic>() ?? const {};
    return InstitutionalStock(
      id: json['id']?.toString() ?? '',
      symbol: instrument['symbol']?.toString() ?? '',
      companyName: instrument['name']?.toString() ?? '',
      price: double.tryParse(json['price']?.toString() ?? '') ?? 0,
      status: json['status']?.toString() ?? 'ACTIVE',
    );
  }

  factory InstitutionalStock.fromInstitutionalJson(
    Map<String, dynamic> json,
  ) => InstitutionalStock(
    id: json['id']?.toString() ?? '',
    symbol: json['symbol']?.toString() ?? '',
    companyName: json['name']?.toString() ?? '',
    price: double.tryParse(json['price']?.toString() ?? '') ?? 0,
    status: json['status']?.toString() ?? '',
    exchange: json['exchange']?.toString() ?? 'NSE',
    direction: json['direction']?.toString() ?? 'UP',
    referencePrice: double.tryParse(json['referencePrice']?.toString() ?? ''),
    expectedReturn: double.tryParse(json['expectedReturn']?.toString() ?? ''),
    reason: json['reason']?.toString(),
  );
}

class OtcOrderRecord {
  const OtcOrderRecord({
    required this.id,
    required this.orderNo,
    required this.symbol,
    required this.quantity,
    required this.price,
    required this.status,
    this.reviewNote,
  });
  final String id;
  final String orderNo;
  final String symbol;
  final int quantity;
  final double price;
  final String status;
  final String? reviewNote;

  factory OtcOrderRecord.fromJson(Map<String, dynamic> json) {
    final instrument =
        (json['instrument'] as Map?)?.cast<String, dynamic>() ?? const {};
    return OtcOrderRecord(
      id: json['id']?.toString() ?? '',
      orderNo: json['orderNo']?.toString() ?? '',
      symbol: instrument['symbol']?.toString() ?? '',
      quantity: int.tryParse(json['quantity']?.toString() ?? '') ?? 0,
      price: double.tryParse(json['price']?.toString() ?? '') ?? 0,
      status: json['status']?.toString() ?? 'PENDING',
      reviewNote: json['reviewNote']?.toString(),
    );
  }
}
