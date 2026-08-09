class InstitutionalStock {
  const InstitutionalStock({
    required this.id,
    required this.symbol,
    required this.companyName,
    required this.price,
    required this.minimumQuantity,
    required this.status,
  });

  final String id;
  final String symbol;
  final String companyName;
  final double price;
  final int minimumQuantity;
  final String status;
}
