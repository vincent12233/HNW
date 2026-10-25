import '../app_config.dart';
import '../models/auth_session.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'salesmartly_platform.dart';
import 'salesmartly_platform_stub.dart'
    if (dart.library.html) 'salesmartly_platform_web.dart'
    if (dart.library.io) 'salesmartly_platform_native.dart';

export 'salesmartly_platform.dart' show SaleSmartlyException;
export 'salesmartly_platform.dart' show SaleSmartlyCustomerIdentity;

/// Shared SaleSmartly facade used by Deposit / floating launcher / logout.
///
/// Android/iOS → MethodChannel native SDK.
/// Web → SaleSmartly JSSDK (`ssq`).
class SaleSmartlyService {
  static final SaleSmartlyPlatform _platform = createSaleSmartlyPlatform();

  Future<void> openChat({
    required AuthSession session,
    String? initialMessage,
    String? scriptUrlOverride,
  }) async {
    final configured = scriptUrlOverride?.trim().isNotEmpty == true
        ? scriptUrlOverride!.trim()
        : AppConfig.saleSmartlyScriptUrl.trim();
    final scriptUrl = normalizeScriptUrl(configured);
    if (scriptUrl.isEmpty) {
      throw const SaleSmartlyException(
        'Customer support is temporarily unavailable. Please try again.',
      );
    }

    await _platform.openChat(
      scriptUrl: scriptUrl,
      identity: identityFor(session),
      initialMessage: initialMessage,
    );
  }

  Future<void> clearUser() async {
    await _platform.clearUser();
  }

  Future<void> closeChat() async {
    await _platform.closeChat();
  }

  /// Accepts a bare URL or a full `<script src="...">` snippet.
  static String normalizeScriptUrl(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return '';
    final match = RegExp(
      r'''src\s*=\s*["']([^"']+)["']''',
      caseSensitive: false,
    ).firstMatch(text);
    return (match?.group(1) ?? text).trim();
  }

  static SaleSmartlyCustomerIdentity identityFor(AuthSession session) {
    final digest = sha256.convert(utf8.encode(session.userId)).toString();
    final reference = 'hnw_${digest.substring(0, 24)}';
    return SaleSmartlyCustomerIdentity(
      customerReference: reference,
      displayName: 'HNW customer ${digest.substring(0, 6).toUpperCase()}',
    );
  }
}
