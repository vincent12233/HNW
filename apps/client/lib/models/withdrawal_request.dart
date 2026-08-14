enum WithdrawalStatus { pending, approved, processing, completed, rejected }

class WithdrawalRequest {
  const WithdrawalRequest({
    required this.id,
    this.orderNo,
    required this.amount,
    required this.bankName,
    required this.accountHolderName,
    required this.maskedAccountNumber,
    required this.ifscCode,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String? orderNo;
  final double amount;

  final String bankName;
  final String accountHolderName;
  final String maskedAccountNumber;
  final String ifscCode;

  final WithdrawalStatus status;
  final DateTime createdAt;

  String get statusLabel {
    switch (status) {
      case WithdrawalStatus.pending:
        return 'Pending';
      case WithdrawalStatus.approved:
        return 'Approved';
      case WithdrawalStatus.processing:
        return 'Processing';
      case WithdrawalStatus.completed:
        return 'Completed';
      case WithdrawalStatus.rejected:
        return 'Rejected';
    }
  }

  String get fundsStatusLabel {
    switch (status) {
      case WithdrawalStatus.pending:
      case WithdrawalStatus.processing:
        return 'Funds frozen';
      case WithdrawalStatus.approved:
      case WithdrawalStatus.completed:
        return 'Deducted from balance';
      case WithdrawalStatus.rejected:
        return 'Freeze released';
    }
  }

  WithdrawalRequest copyWith({
    String? id,
    String? orderNo,
    double? amount,
    String? bankName,
    String? accountHolderName,
    String? maskedAccountNumber,
    String? ifscCode,
    WithdrawalStatus? status,
    DateTime? createdAt,
  }) {
    return WithdrawalRequest(
      id: id ?? this.id,
      orderNo: orderNo ?? this.orderNo,
      amount: amount ?? this.amount,
      bankName: bankName ?? this.bankName,
      accountHolderName: accountHolderName ?? this.accountHolderName,
      maskedAccountNumber: maskedAccountNumber ?? this.maskedAccountNumber,
      ifscCode: ifscCode ?? this.ifscCode,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'orderNo': orderNo,
      'amount': amount,
      'bankName': bankName,
      'accountHolderName': accountHolderName,
      'maskedAccountNumber': maskedAccountNumber,
      'ifscCode': ifscCode,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory WithdrawalRequest.fromJson(Map<String, dynamic> json) {
    final rawStatus = json['status']?.toString().toLowerCase() ?? 'pending';
    final rawAccountNumber = json['accountNumber']?.toString() ?? '';
    final maskedAccountNumber =
        json['maskedAccountNumber']?.toString() ??
        (rawAccountNumber.length > 4
            ? '****${rawAccountNumber.substring(rawAccountNumber.length - 4)}'
            : rawAccountNumber);

    return WithdrawalRequest(
      id: json['id']?.toString() ?? '',
      orderNo: json['orderNo']?.toString(),
      amount:
          (json['amount'] as num?)?.toDouble() ??
          double.tryParse(json['amount']?.toString() ?? '') ??
          0,
      bankName: json['bankName']?.toString() ?? '',
      accountHolderName: json['accountHolderName']?.toString() ?? '',
      maskedAccountNumber: maskedAccountNumber,
      ifscCode: json['ifscCode']?.toString() ?? '',
      status: WithdrawalStatus.values.firstWhere(
        (status) => status.name == rawStatus,
        orElse: () => WithdrawalStatus.pending,
      ),
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}
