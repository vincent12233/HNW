import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../app_config.dart';
import '../models/auth_session.dart';

class SaleSmartlyService {
  static const MethodChannel _channel = MethodChannel(
    'india_trading/salesmartly',
  );

  Future<void> openChat({
    required AuthSession session,
    String? initialMessage,
  }) async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      throw const SaleSmartlyException(
        'Customer service is available in the Android and iOS apps.',
      );
    }

    final scriptUrl = AppConfig.saleSmartlyScriptUrl.trim();
    if (scriptUrl.isEmpty) {
      throw const SaleSmartlyException(
        'Customer service is not configured. Set SALESMARTLY_SCRIPT_URL when building the app.',
      );
    }

    try {
      await _channel.invokeMethod<void>('openChat', {
        'scriptUrl': scriptUrl,
        'userId': session.userId,
        'userName': session.fullName,
        'phone': session.phone,
        'accountNumber': session.accountNumber,
        'initialMessage': initialMessage?.trim() ?? '',
      });
    } on PlatformException catch (error) {
      throw SaleSmartlyException(
        error.message ?? 'Unable to open customer service.',
      );
    }
  }

  Future<void> clearUser() async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return;
    }
    try {
      await _channel.invokeMethod<void>('clearUser');
    } on PlatformException {
      // Session deletion must still succeed if the native SDK is unavailable.
    }
  }
}

class SaleSmartlyException implements Exception {
  const SaleSmartlyException(this.message);

  final String message;
}
