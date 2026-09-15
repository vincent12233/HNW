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
    String? scriptUrlOverride,
  }) async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      throw const SaleSmartlyException(
        'Customer service is available in the Android and iOS apps.',
      );
    }

    final configured = scriptUrlOverride?.trim().isNotEmpty == true
        ? scriptUrlOverride!.trim()
        : AppConfig.saleSmartlyScriptUrl.trim();
    final scriptUrl = _normalizeScriptUrl(configured);
    if (scriptUrl.isEmpty) {
      throw const SaleSmartlyException(
        'Customer service is not configured. Ask an administrator to set the SaleSmartly script URL.',
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

  /// Accepts a bare URL or a full `<script src="...">` snippet.
  static String _normalizeScriptUrl(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return '';
    final match = RegExp(
      r'''src\s*=\s*["']([^"']+)["']''',
      caseSensitive: false,
    ).firstMatch(text);
    return (match?.group(1) ?? text).trim();
  }
}

class SaleSmartlyException implements Exception {
  const SaleSmartlyException(this.message);

  final String message;
}
