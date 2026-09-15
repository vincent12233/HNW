class InstitutionalStock {
  const InstitutionalStock({
    required this.id,
    required this.symbol,
    required this.companyName,
    required this.price,
    this.marketPrice = 0,
    this.expectedReturn,
    this.minimumQuantity,
    required this.status,
    this.exchange = 'NSE',
    this.instrumentId,
  });

  final String id;
  final String symbol;
  final String companyName;
  /// Live settlement / trade price (realtime lastPrice).
  final double price;
  final double marketPrice;
  final double? expectedReturn;
  @Deprecated('Quantity limits are not used for Inst. or OTC orders')
  final int? minimumQuantity;
  final String status;
  final String exchange;
  final String? instrumentId;

  factory InstitutionalStock.fromOtcJson(Map<String, dynamic> json) {
    final instrument =
        (json['instrument'] as Map?)?.cast<String, dynamic>() ?? const {};
    return InstitutionalStock(
      id: json['id']?.toString() ?? '',
      symbol: instrument['symbol']?.toString() ?? '',
      companyName: instrument['name']?.toString() ?? '',
      price: double.tryParse(json['price']?.toString() ?? '') ?? 0,
      marketPrice: double.tryParse(json['marketPrice']?.toString() ?? '') ?? 0,
      status: json['status']?.toString() ?? 'ACTIVE',
      exchange: instrument['exchange']?.toString() ?? 'BSE',
      instrumentId: instrument['id']?.toString(),
    );
  }

  factory InstitutionalStock.fromInstitutionalJson(Map<String, dynamic> json) =>
      InstitutionalStock(
        id: json['id']?.toString() ?? '',
        symbol: json['symbol']?.toString() ?? '',
        companyName: json['name']?.toString() ?? '',
        price: double.tryParse(json['price']?.toString() ?? '') ?? 0,
        marketPrice:
            double.tryParse(json['marketPrice']?.toString() ?? '') ?? 0,
        expectedReturn:
            double.tryParse(json['expectedReturn']?.toString() ?? ''),
        status: json['status']?.toString() ?? '',
        exchange: json['exchange']?.toString() ?? 'NSE',
        instrumentId: json['instrumentId']?.toString(),
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
