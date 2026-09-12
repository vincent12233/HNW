enum IpoStatus { open, upcoming, closed }

class Ipo {
  const Ipo({
    required this.id,
    required this.companyName,
    required this.symbol,
    required this.status,
    required this.marketPrice,
    required this.subscriptionPrice,
    required this.lotSize,
  });

  final String id;
  final String companyName;
  final String symbol;
  final IpoStatus status;
  final double marketPrice;
  final double subscriptionPrice;
  final int lotSize;

  double get discountAmount {
    final value = marketPrice - subscriptionPrice;

    if (value <= 0) {
      return 0;
    }

    return value;
  }

  double get discountPercent {
    if (marketPrice <= 0 || subscriptionPrice >= marketPrice) {
      return 0;
    }

    return ((marketPrice - subscriptionPrice) / marketPrice) * 100;
  }

  factory Ipo.fromApiJson(Map<String, dynamic> json) {
    final rawStatus = json['status']?.toString().toUpperCase() ?? 'OPEN';
    return Ipo(
      id: json['id']?.toString() ?? '',
      companyName: json['companyName']?.toString() ?? '',
      symbol: json['symbol']?.toString() ?? '',
      status: rawStatus == 'PUBLISHED' || rawStatus == 'OPEN'
          ? IpoStatus.open
          : rawStatus == 'CLOSED' ||
                rawStatus == 'LISTED' ||
                rawStatus == 'ALLOTMENT_DONE'
          ? IpoStatus.closed
          : IpoStatus.upcoming,
      marketPrice: _doubleValue(json['marketPrice'] ?? json['issuePrice']),
      subscriptionPrice: _doubleValue(json['issuePrice']),
      lotSize: _intValue(json['lotSize']),
    );
  }

  String get statusLabel {
    switch (status) {
      case IpoStatus.open:
        return 'Open';
      case IpoStatus.upcoming:
        return 'Upcoming';
      case IpoStatus.closed:
        return 'Closed';
    }
  }
}

enum IpoApplicationStatus {
  applied,
  allocated,
  completed,
  notAllotted,
  cancelled,
}

class IpoApplication {
  const IpoApplication({
    required this.id,
    required this.ipoId,
    required this.companyName,
    required this.symbol,
    required this.appliedQuantity,
    required this.allocatedQuantity,
    required this.subscriptionPrice,
    required this.paidAmount,
    required this.status,
  });

  final String id;
  final String ipoId;
  final String companyName;
  final String symbol;
  final int appliedQuantity;
  final int allocatedQuantity;
  final double subscriptionPrice;
  final double paidAmount;
  final IpoApplicationStatus status;

  double get allocatedAmount {
    return allocatedQuantity * subscriptionPrice;
  }

  double get remainingAmount {
    final value = allocatedAmount - paidAmount;

    if (value <= 0) {
      return 0;
    }

    return value;
  }

  bool get hasAllocation {
    return allocatedQuantity > 0 &&
        (status == IpoApplicationStatus.allocated ||
            status == IpoApplicationStatus.completed);
  }

  bool get needsSubscription {
    return status == IpoApplicationStatus.allocated &&
        allocatedQuantity > 0 &&
        remainingAmount > 0;
  }

  bool get isFullyPaid {
    return allocatedQuantity > 0 &&
        allocatedAmount > 0 &&
        paidAmount >= allocatedAmount;
  }

  bool get shouldMoveToHoldings {
    return status == IpoApplicationStatus.completed &&
        allocatedQuantity > 0 &&
        isFullyPaid;
  }

  IpoApplication copyWith({
    String? id,
    String? ipoId,
    String? companyName,
    String? symbol,
    int? appliedQuantity,
    int? allocatedQuantity,
    double? subscriptionPrice,
    double? paidAmount,
    IpoApplicationStatus? status,
  }) {
    return IpoApplication(
      id: id ?? this.id,
      ipoId: ipoId ?? this.ipoId,
      companyName: companyName ?? this.companyName,
      symbol: symbol ?? this.symbol,
      appliedQuantity: appliedQuantity ?? this.appliedQuantity,
      allocatedQuantity: allocatedQuantity ?? this.allocatedQuantity,
      subscriptionPrice: subscriptionPrice ?? this.subscriptionPrice,
      paidAmount: paidAmount ?? this.paidAmount,
      status: status ?? this.status,
    );
  }

  String get statusLabel {
    switch (status) {
      case IpoApplicationStatus.applied:
        return 'Applied';
      case IpoApplicationStatus.allocated:
        return 'Allocated';
      case IpoApplicationStatus.completed:
        return 'Completed';
      case IpoApplicationStatus.notAllotted:
        return 'Not Allotted';
      case IpoApplicationStatus.cancelled:
        return 'Cancelled';
    }
  }

  factory IpoApplication.fromApiJson(Map<String, dynamic> json) {
    final ipo = (json['ipo'] as Map?)?.cast<String, dynamic>() ?? {};
    final rawStatus = json['status']?.toString().toUpperCase() ?? 'PENDING';
    final rawPaymentStatus =
        json['paymentStatus']?.toString().toUpperCase() ?? 'PENDING';
    final allocatedQuantity = _intValue(json['allocatedQuantity']);
    final subscriptionPrice = _doubleValue(
      json['allocatedPrice'] ?? ipo['issuePrice'],
    );
    final allocatedAmount = _doubleValue(json['allocatedAmount']) > 0
        ? _doubleValue(json['allocatedAmount'])
        : allocatedQuantity * subscriptionPrice;
    final debt = (json['debt'] as Map?)?.cast<String, dynamic>();
    final outstandingDebt =
        _doubleValue(debt?['amount']) - _doubleValue(debt?['paidAmount']);
    final paidAmount = allocatedAmount > 0
        ? (allocatedAmount - (outstandingDebt > 0 ? outstandingDebt : 0))
        : 0.0;

    return IpoApplication(
      id: json['id']?.toString() ?? '',
      ipoId: (ipo['id'] ?? json['ipoId'] ?? '').toString(),
      companyName: ipo['companyName']?.toString() ?? '',
      symbol: ipo['symbol']?.toString() ?? '',
      appliedQuantity: _intValue(json['quantity']),
      allocatedQuantity: allocatedQuantity,
      subscriptionPrice: subscriptionPrice,
      paidAmount: rawPaymentStatus == 'PAID' ? allocatedAmount : paidAmount,
      status: rawStatus == 'ALLOTTED'
          ? rawPaymentStatus == 'PAID'
                ? IpoApplicationStatus.completed
                : IpoApplicationStatus.allocated
          : rawStatus == 'REJECTED'
          ? IpoApplicationStatus.notAllotted
          : IpoApplicationStatus.applied,
    );
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
