class AccountTransaction {
  const AccountTransaction({
    required this.id,
    required this.type,
    required this.status,
    required this.amount,
    required this.balanceAfter,
    required this.createdAt,
    this.referenceId,
    this.note,
  });

  final String id;
  final String type;
  final String status;
  final double amount;
  final double balanceAfter;
  final String? referenceId;
  final String? note;
  final DateTime createdAt;

  factory AccountTransaction.fromJson(Map<String, dynamic> json) =>
      AccountTransaction(
        id: json['id']?.toString() ?? '',
        type: json['type']?.toString() ?? '',
        status: json['status']?.toString() ?? '',
        amount: double.tryParse(json['amount']?.toString() ?? '') ?? 0,
        balanceAfter:
            double.tryParse(json['balanceAfter']?.toString() ?? '') ?? 0,
        referenceId: json['referenceId']?.toString(),
        note: json['note']?.toString(),
        createdAt:
            DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );
}
