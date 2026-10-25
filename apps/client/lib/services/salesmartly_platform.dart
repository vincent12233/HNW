class SaleSmartlyException implements Exception {
  const SaleSmartlyException(this.message);

  final String message;
}

class SaleSmartlyCustomerIdentity {
  const SaleSmartlyCustomerIdentity({
    required this.customerReference,
    required this.displayName,
  });

  final String customerReference;
  final String displayName;
}

/// Platform bridge for SaleSmartly. Factory selected via conditional import.
abstract class SaleSmartlyPlatform {
  Future<void> openChat({
    required String scriptUrl,
    required SaleSmartlyCustomerIdentity identity,
    String? initialMessage,
  });

  Future<void> clearUser();

  Future<void> closeChat();
}
