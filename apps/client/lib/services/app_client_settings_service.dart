import 'dart:convert';

import 'package:http/http.dart' as http;

import '../app_config.dart';

class AppClientSettings {
  const AppClientSettings({
    required this.platform,
    required this.minVersion,
    required this.latestVersion,
    required this.forceUpdate,
    required this.maintenanceMode,
    this.maintenanceMessage,
    this.supportUrl,
  });

  final String platform;
  final String minVersion;
  final String latestVersion;
  final bool forceUpdate;
  final bool maintenanceMode;
  final String? maintenanceMessage;
  final String? supportUrl;

  /// Safe defaults when API is unavailable — never lock the user out.
  static const safeDefaults = AppClientSettings(
    platform: 'WEB',
    minVersion: '0.0.0',
    latestVersion: '0.0.0',
    forceUpdate: false,
    maintenanceMode: false,
  );

  factory AppClientSettings.fromJson(Map<String, dynamic> json) {
    return AppClientSettings(
      platform: '${json['platform'] ?? 'WEB'}',
      minVersion: '${json['minVersion'] ?? '0.0.0'}',
      latestVersion: '${json['latestVersion'] ?? '0.0.0'}',
      forceUpdate: json['forceUpdate'] == true,
      maintenanceMode: json['maintenanceMode'] == true,
      maintenanceMessage: json['maintenanceMessage']?.toString(),
      supportUrl: json['supportUrl']?.toString(),
    );
  }
}

/// Parses app settings; failures return [AppClientSettings.safeDefaults].
class AppClientSettingsService {
  AppClientSettingsService._();

  static final AppClientSettingsService instance = AppClientSettingsService._();

  Future<AppClientSettings> load({String platform = 'WEB'}) async {
    final normalized = platform.trim().toUpperCase();
    try {
      final response = await http
          .get(
            Uri.parse(
              '${AppConfig.apiBaseUrl}/app-settings?platform=$normalized',
            ),
          )
          .timeout(const Duration(seconds: 12));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return AppClientSettings.safeDefaults;
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return AppClientSettings.safeDefaults;
      return AppClientSettings.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return AppClientSettings.safeDefaults;
    }
  }
}
