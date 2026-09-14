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
  // This is enabled only by the local Docker Web build. Production mobile and
  // hosted Web builds keep the HTTPS requirement enforced.
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
      final host = uri?.host ?? '';
      final isRelativeApi =
          uri != null &&
          uri.scheme.isEmpty &&
          uri.host.isEmpty &&
          uri.path.startsWith('/');
      final isLocalHttp =
          uri?.scheme == 'http' &&
          (host == 'localhost' ||
              host == '127.0.0.1' ||
              host.startsWith('10.') ||
              host.startsWith('192.168.') ||
              host.startsWith('172.16.') ||
              host.startsWith('172.17.') ||
              host.startsWith('172.18.') ||
              host.startsWith('172.19.') ||
              host.startsWith('172.2') ||
              host.startsWith('172.3'));
      if (kReleaseMode &&
          !_allowInsecureApi &&
          !isRelativeApi &&
          !isLocalHttp &&
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

  // Brand — keep a single blue finance identity across client + admin.
  static const Color primaryColor = Color(0xFF165DFF);
  static const Color primaryHoverColor = Color(0xFF1248D6);
  static const Color primaryDarkColor = Color(0xFF071F4A);
  static const Color primaryGradientEnd = Color(0xFF1849A9);
  static const Color primarySoftColor = Color(0xFFE8F0FF);

  // Surfaces
  static const Color backgroundColor = Color(0xFFF3F6FB);
  static const Color surfaceColor = Colors.white;
  static const Color surfaceMutedColor = Color(0xFFF8FAFC);
  static const Color borderColor = Color(0xFFE1E7F0);
  static const Color dividerColor = Color(0xFFE8EDF5);

  // Text
  static const Color textPrimaryColor = Color(0xFF101828);
  static const Color textSecondaryColor = Color(0xFF5D6B82);
  static const Color textTertiaryColor = Color(0xFF98A2B3);

  // Status
  static const Color gainColor = Color(0xFF0A7A56);
  static const Color lossColor = Color(0xFFD92D4B);
  static const Color warningColor = Color(0xFFD97706);
  static const Color neutralColor = Color(0xFF667085);
  static const Color chartGainColor = Color(0xFF0A7A56);
  static const Color chartLossColor = Color(0xFFD92D4B);

  // Module accents (blue-family + status only — no purple chrome)
  static const Color moduleTrades = primaryColor;
  static const Color moduleInstitutional = Color(0xFF1849A9);
  static const Color moduleHoldings = gainColor;
  static const Color modulePending = warningColor;
  static const Color moduleOrderBook = Color(0xFF334155);
  static const Color moduleOtc = Color(0xFF0F766E);
  static const Color moduleIpo = lossColor;
  static const Color moduleHistory = Color(0xFFB45309);
  static const Color moduleLedger = neutralColor;

  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryColor, primaryGradientEnd, primaryDarkColor],
    stops: [0, 0.55, 1],
  );

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryDarkColor, primaryGradientEnd, primaryColor],
    stops: [0, 0.55, 1],
  );

  static List<BoxShadow> get softShadow => const [
        BoxShadow(
          color: Color(0x14071F4A),
          blurRadius: 18,
          offset: Offset(0, 8),
        ),
      ];

  static BorderRadius get cardRadius => BorderRadius.circular(16);
  static BorderRadius get chipRadius => BorderRadius.circular(10);
}
