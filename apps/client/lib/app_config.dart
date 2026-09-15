import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AppConfig {
  static const String appName = 'India Trading';
  static const String shortName = 'IT';
  static const String slogan = 'Professional. Fast. Simple.';
  static const String _configuredApiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );
  // Dev-only: allow http:// API hosts when ALLOW_INSECURE_API=true.
  // Production mobile and hosted Web builds keep HTTPS enforced.
  static const bool _allowInsecureApi = bool.fromEnvironment(
    'ALLOW_INSECURE_API',
    defaultValue: false,
  );
  static const String googleClientId = String.fromEnvironment(
    'GOOGLE_CLIENT_ID',
    defaultValue: '',
  );
  static const String saleSmartlyScriptUrl = String.fromEnvironment(
    'SALESMARTLY_SCRIPT_URL',
    defaultValue: '',
  );

  static String get apiBaseUrl {
    if (_configuredApiBaseUrl.isNotEmpty) {
      final uri = Uri.tryParse(_configuredApiBaseUrl);
      final isRelativeApi =
          uri != null &&
          uri.scheme.isEmpty &&
          uri.host.isEmpty &&
          uri.path.startsWith('/');
      if (kReleaseMode &&
          !_allowInsecureApi &&
          !isRelativeApi &&
          uri?.scheme != 'https') {
        throw StateError('Release builds require an HTTPS API_BASE_URL');
      }
      return _configuredApiBaseUrl;
    }

    if (kReleaseMode) {
      throw StateError('API_BASE_URL is required for release builds');
    }

    if (kIsWeb) {
      return 'http://localhost:3000';
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000';
    }

    return 'http://localhost:3000';
  }

  static const Color primaryColor = Color(0xFF165DFF);
  static const Color primaryDarkColor = Color(0xFF071F4A);
  static const Color primaryGradientEnd = Color(0xFF1849A9);
  static const Color surfaceColor = Colors.white;
  static const Color borderColor = Color(0xFFE1E7F0);
  static const Color gainColor = Color(0xFF087F5B);
  static const Color lossColor = Color(0xFFD92D4B);
  static const Color neutralColor = Color(0xFF667085);
  static const Color backgroundColor = Color(0xFFF4F7FB);
  static const Color textPrimaryColor = Color(0xFF101828);
  static const Color textSecondaryColor = Color(0xFF5D6B82);
  static const Color chartGainColor = Color(0xFF43C987);
}
