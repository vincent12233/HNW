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
      if (kReleaseMode && !isSafeReleaseApiBaseUrl(_configuredApiBaseUrl)) {
        throw StateError(
          'Release builds require a public HTTPS API_BASE_URL or a same-origin path',
        );
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

  @visibleForTesting
  static bool isSafeReleaseApiBaseUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null) return false;

    final isSameOriginPath =
        uri.scheme.isEmpty &&
        uri.host.isEmpty &&
        uri.path.startsWith('/') &&
        !uri.path.startsWith('//');
    if (isSameOriginPath) return true;

    if (uri.scheme != 'https' || uri.host.isEmpty || uri.userInfo.isNotEmpty) {
      return false;
    }
    return !_isLocalOrPrivateHost(uri.host);
  }

  static bool _isLocalOrPrivateHost(String value) {
    final host = value.toLowerCase().replaceAll(RegExp(r'^\[|\]$'), '');
    if (host == 'localhost' ||
        host == '0.0.0.0' ||
        host == '127.0.0.1' ||
        host == '::' ||
        host == '::1' ||
        host.endsWith('.localhost') ||
        host.endsWith('.local') ||
        host.endsWith('.internal')) {
      return true;
    }

    if (host.contains(':')) {
      if (host.startsWith('::ffff:')) {
        return _isLocalOrPrivateHost(host.substring('::ffff:'.length));
      }
      return host.startsWith('fc') ||
          host.startsWith('fd') ||
          RegExp(r'^fe[89ab]').hasMatch(host) ||
          host.startsWith('2001:db8:');
    }

    final octets = host.split('.').map(int.tryParse).toList();
    if (octets.length != 4 || octets.any((octet) => octet == null)) {
      return false;
    }
    final parts = octets.cast<int>();
    if (parts.any((part) => part < 0 || part > 255)) return true;
    return parts[0] == 0 ||
        parts[0] == 10 ||
        (parts[0] == 100 && parts[1] >= 64 && parts[1] <= 127) ||
        parts[0] == 127 ||
        (parts[0] == 169 && parts[1] == 254) ||
        (parts[0] == 172 && parts[1] >= 16 && parts[1] <= 31) ||
        (parts[0] == 192 &&
            (parts[1] == 168 ||
                (parts[1] == 0 && (parts[2] == 0 || parts[2] == 2)))) ||
        (parts[0] == 198 &&
            (parts[1] == 18 ||
                parts[1] == 19 ||
                (parts[1] == 51 && parts[2] == 100))) ||
        (parts[0] == 203 && parts[1] == 0 && parts[2] == 113) ||
        parts[0] >= 224;
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
