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
      final configured = _configuredApiBaseUrl.trim();
      if (kReleaseMode && !isSafeReleaseApiBaseUrl(configured)) {
        throw StateError(
          'Release builds require a public HTTPS API_BASE_URL or a same-origin path',
        );
      }
      return configured;
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
    final normalized = value.trim();
    final uri = Uri.tryParse(normalized);
    if (uri == null) return false;

    final isSameOriginPath =
        uri.scheme.isEmpty &&
        uri.host.isEmpty &&
        uri.path.startsWith('/') &&
        !uri.path.startsWith('//') &&
        uri.path != '/' &&
        uri.query.isEmpty &&
        uri.fragment.isEmpty;
    if (isSameOriginPath) return true;

    if (uri.scheme != 'https' || uri.host.isEmpty || uri.userInfo.isNotEmpty) {
      return false;
    }
    return !_isLocalOrPrivateHost(uri.host);
  }

  static bool _isLocalOrPrivateHost(String value) {
    final host = value
        .toLowerCase()
        .replaceAll(RegExp(r'^\[|\]$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
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
      return _isPrivateIpv6(host);
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

  static bool _isPrivateIpv6(String host) {
    final groups = _parseIpv6(host);
    if (groups == null) return true;

    final isUnspecified = groups.every((group) => group == 0);
    final isLoopback =
        groups.take(7).every((group) => group == 0) && groups[7] == 1;
    final isMappedIpv4 =
        groups.take(5).every((group) => group == 0) && groups[5] == 0xffff;
    if (isUnspecified || isLoopback) return true;
    if (isMappedIpv4) {
      final address =
          '${groups[6] >> 8}.${groups[6] & 0xff}.'
          '${groups[7] >> 8}.${groups[7] & 0xff}';
      return _isLocalOrPrivateHost(address);
    }

    final first = groups[0];
    return (first & 0xfe00) == 0xfc00 ||
        (first & 0xffc0) == 0xfe80 ||
        (first == 0x2001 && groups[1] == 0x0db8) ||
        (first & 0xff00) == 0xff00;
  }

  static List<int>? _parseIpv6(String host) {
    if (host.contains('%')) return null;
    final halves = host.split('::');
    if (halves.length > 2) return null;
    final left = _parseIpv6Groups(halves[0]);
    final right = halves.length == 2 ? _parseIpv6Groups(halves[1]) : <int>[];
    if (left == null || right == null) return null;
    if (halves.length == 1) {
      return left.length == 8 ? left : null;
    }
    final missing = 8 - left.length - right.length;
    if (missing < 1) return null;
    return [...left, ...List.filled(missing, 0), ...right];
  }

  static List<int>? _parseIpv6Groups(String value) {
    if (value.isEmpty) return <int>[];
    final groups = <int>[];
    for (final part in value.split(':')) {
      if (part.isEmpty) return null;
      if (part.contains('.')) {
        final octets = part.split('.').map(int.tryParse).toList();
        if (octets.length != 4 || octets.any((octet) => octet == null)) {
          return null;
        }
        final bytes = octets.cast<int>();
        if (bytes.any((byte) => byte < 0 || byte > 255)) return null;
        groups.add((bytes[0] << 8) | bytes[1]);
        groups.add((bytes[2] << 8) | bytes[3]);
      } else {
        final group = int.tryParse(part, radix: 16);
        if (group == null || group < 0 || group > 0xffff) return null;
        groups.add(group);
      }
    }
    return groups;
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
