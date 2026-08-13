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
      return _configuredApiBaseUrl;
    }

    if (kIsWeb) {
      return 'http://localhost:3000';
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000';
    }

    return 'http://localhost:3000';
  }

  static const Color primaryColor = Color(0xFF1769FF);
  static const Color primaryDarkColor = Color(0xFF123D8A);
  static const Color surfaceColor = Colors.white;
  static const Color borderColor = Color(0xFFE7EAF0);
  static const Color gainColor = Color(0xFF16A34A);
  static const Color lossColor = Color(0xFFDC2626);
  static const Color neutralColor = Color(0xFF6B7280);
  static const Color backgroundColor = Color(0xFFF7F8FC);
  static const Color textPrimaryColor = Color(0xFF111827);
}
