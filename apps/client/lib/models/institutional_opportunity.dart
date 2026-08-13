class InstitutionalStock {
  const InstitutionalStock({
    required this.id,
    required this.symbol,
    required this.companyName,
    required this.price,
    this.minimumQuantity,
    required this.status,
    this.exchange = 'NSE',
    this.otcTiers = const [],
  });

  final String id;
  final String symbol;
  final String companyName;
  final double price;
  @Deprecated('Quantity limits are not used for Inst. or OTC orders')
  final int? minimumQuantity;
  final String status;
  final String exchange;
  final List<OtcPriceTier> otcTiers;

  factory InstitutionalStock.fromOtcJson(Map<String, dynamic> json) {
    final instrument =
        (json['instrument'] as Map?)?.cast<String, dynamic>() ?? const {};
    final tiers = (json['tiers'] as List? ?? const [])
        .whereType<Map>()
        .map((row) => OtcPriceTier.fromJson(Map<String, dynamic>.from(row)))
        .toList();
    return InstitutionalStock(
      id: json['id']?.toString() ?? '',
      symbol: instrument['symbol']?.toString() ?? '',
      companyName: instrument['name']?.toString() ?? '',
      price: double.tryParse(json['price']?.toString() ?? '') ?? 0,
      status: json['status']?.toString() ?? 'ACTIVE',
      exchange: instrument['exchange']?.toString() ?? 'BSE',
      otcTiers: tiers,
    );
  }

  factory InstitutionalStock.fromInstitutionalJson(Map<String, dynamic> json) =>
      InstitutionalStock(
        id: json['id']?.toString() ?? '',
        symbol: json['symbol']?.toString() ?? '',
        companyName: json['name']?.toString() ?? '',
        price: double.tryParse(json['price']?.toString() ?? '') ?? 0,
        status: json['status']?.toString() ?? '',
        exchange: json['exchange']?.toString() ?? 'NSE',
      );
}

class OtcPriceTier {
  const OtcPriceTier({
    required this.tier,
    required this.price,
    required this.profit,
  });
  final int tier;
  final double price;
  final double profit;

  factory OtcPriceTier.fromJson(Map<String, dynamic> json) => OtcPriceTier(
    tier: int.tryParse(json['tier']?.toString() ?? '') ?? 1,
    price: double.tryParse(json['price']?.toString() ?? '') ?? 0,
    profit: double.tryParse(json['profit']?.toString() ?? '') ?? 0,
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
