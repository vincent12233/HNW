import '../models/auth_session.dart';

class SaleSmartlyException implements Exception {
  const SaleSmartlyException(this.message);

  final String message;
}

/// Platform bridge for SaleSmartly. Factory selected via conditional import.
abstract class SaleSmartlyPlatform {
  Future<void> openChat({
    required String scriptUrl,
    required AuthSession session,
    String? initialMessage,
  });

  Future<void> clearUser();

  Future<void> closeChat();
}
