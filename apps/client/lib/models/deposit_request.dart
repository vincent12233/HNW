class DepositRequest {
  const DepositRequest({
    required this.id,
    required this.amount,
    required this.status,
    required this.createdAt,
    this.paymentMethod,
    this.referenceId,
    this.note,
  });

  final String id;
  final double amount;
  final String status;
  final DateTime createdAt;
  final String? paymentMethod;
  final String? referenceId;
  final String? note;

  factory DepositRequest.fromJson(Map<String, dynamic> json) {
    final amount = _amount(json['amount']);
    return DepositRequest(
      id: json['id']?.toString() ?? '',
      amount: amount,
      status: json['status']?.toString() ?? '',
      paymentMethod: _optionalText(json['paymentMethod']),
      referenceId: _optionalText(json['referenceId']),
      note: _optionalText(json['note']),
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  static double _amount(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String? _optionalText(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }
}
