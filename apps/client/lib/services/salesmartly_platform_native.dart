import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/auth_session.dart';
import 'salesmartly_platform.dart';

SaleSmartlyPlatform createSaleSmartlyPlatform() =>
    _SaleSmartlyNativePlatform();

/// Android / iOS MethodChannel bridge. Unchanged channel contract.
final class _SaleSmartlyNativePlatform implements SaleSmartlyPlatform {
  static const MethodChannel _channel = MethodChannel(
    'india_trading/salesmartly',
  );

  @override
  Future<void> openChat({
    required String scriptUrl,
    required AuthSession session,
    String? initialMessage,
  }) async {
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      throw const SaleSmartlyException(
        'Customer support is temporarily unavailable. Please try again.',
      );
    }
    try {
      await _channel.invokeMethod<void>('openChat', {
        'scriptUrl': scriptUrl,
        'userId': session.userId,
        'userName': session.fullName,
        'phone': session.phone,
        'initialMessage': initialMessage?.trim() ?? '',
      });
    } on PlatformException {
      throw const SaleSmartlyException(
        'Customer support is temporarily unavailable. Please try again.',
      );
    }
  }

  @override
  Future<void> clearUser() async {
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }
    try {
      await _channel.invokeMethod<void>('clearUser');
    } on PlatformException {
      // Session deletion must still succeed if the native SDK is unavailable.
    }
  }

  @override
  Future<void> closeChat() async {
    // Native hosts manage their own chat Activity / view controller.
  }
}
