import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AppConfig {
  static const String appName = 'India Trading App';
  static const String shortName = 'IT';
  static const String slogan = 'Professional. Fast. Simple.';
  static const String _configuredApiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );
  static const String googleClientId = String.fromEnvironment(
    'GOOGLE_CLIENT_ID',
    defaultValue: '',
  );

  static String get apiBaseUrl {
    if (_configuredApiBaseUrl.isNotEmpty) {
      final uri = Uri.tryParse(_configuredApiBaseUrl);
      if (kReleaseMode && uri?.scheme != 'https') {
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

  static const Color primaryColor = Color(0xFF0055F5);
  static const Color primaryDarkColor = Color(0xFF062477);
  static const Color primaryGradientEnd = Color(0xFF0346C9);
  static const Color surfaceColor = Colors.white;
  static const Color borderColor = Color(0xFFE8ECF2);
  static const Color gainColor = Color(0xFF12A95B);
  static const Color lossColor = Color(0xFFE83945);
  static const Color neutralColor = Color(0xFF667085);
  static const Color backgroundColor = Colors.white;
  static const Color textPrimaryColor = Color(0xFF101638);
  static const Color textSecondaryColor = Color(0xFF667085);
  static const Color chartGainColor = Color(0xFF43C987);
}
