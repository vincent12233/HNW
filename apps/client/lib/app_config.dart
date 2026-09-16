import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'theme/app_colors.dart';

class AppConfig {
  static const String appName = 'India Trading';
  static const String shortName = 'IT';
  static const String slogan = 'Professional. Fast. Simple.';

  /// Build / package version label (keep aligned with pubspec `version`).
  /// Not sourced from CMS `about.app_version` (marketing copy only).
  static const String appVersion = '1.0.5';
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

  // Legacy aliases — delegate to [AppColors] (single source of truth).
  static const Color primaryColor = AppColors.brandPrimary;
  static const Color primaryDarkColor = AppColors.brandDark;
  static const Color primaryGradientEnd = AppColors.brandGradientEnd;
  static const Color surfaceColor = AppColors.surface;
  static const Color borderColor = AppColors.border;
  static const Color gainColor = AppColors.gain;
  static const Color lossColor = AppColors.loss;
  static const Color neutralColor = AppColors.neutral;
  static const Color backgroundColor = AppColors.background;
  static const Color textPrimaryColor = AppColors.textPrimary;
  static const Color textSecondaryColor = AppColors.textSecondary;
  static const Color chartGainColor = AppColors.chartGain;
}
