import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import '../app_config.dart';
import 'app_version.dart';

/// Returns a launchable http(s) update destination, or null if missing/invalid.
/// Never treats supportUrl as an update destination.
Uri? parseValidUpdateUrl(String? raw) {
  final trimmed = raw?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  final uri = Uri.tryParse(trimmed);
  if (uri == null) return null;
  if (uri.scheme != 'http' && uri.scheme != 'https') return null;
  if (uri.host.isEmpty) return null;
  return uri;
}

class AppClientSettings {
  const AppClientSettings({
    required this.platform,
    required this.minVersion,
    required this.latestVersion,
    required this.forceUpdate,
    required this.maintenanceMode,
    this.maintenanceMessage,
    this.supportUrl,
    this.updateUrl,
  });

  final String platform;
  final String minVersion;
  final String latestVersion;
  final bool forceUpdate;
  final bool maintenanceMode;
  final String? maintenanceMessage;
  final String? supportUrl;

  /// Store / download destination for Update CTA (http/https). Optional.
  final String? updateUrl;

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
      updateUrl: json['updateUrl']?.toString(),
    );
  }

  Uri? get validUpdateUri => parseValidUpdateUrl(updateUrl);
}

/// Bootstrap + memory-cached client settings (ChangeNotifier singleton).
class AppClientSettingsService extends ChangeNotifier {
  AppClientSettingsService._();

  static final AppClientSettingsService instance = AppClientSettingsService._();

  AppClientSettings _settings = AppClientSettings.safeDefaults;
  String _currentVersion = AppConfig.appVersion;
  AppSettingsGate _gate = AppSettingsGate.none;
  bool _optionalUpdateDismissed = false;
  bool _forceUpdateContinued = false;
  bool _bootstrapped = false;

  AppClientSettings get settings => _settings;
  String get currentVersion => _currentVersion;
  AppSettingsGate get gate => _gate;
  bool get optionalUpdateDismissed => _optionalUpdateDismissed;
  bool get forceUpdateContinued => _forceUpdateContinued;
  bool get bootstrapped => _bootstrapped;

  static String detectPlatform() {
    if (kIsWeb) return 'WEB';
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return 'IOS';
      case TargetPlatform.android:
        return 'ANDROID';
      default:
        return 'WEB';
    }
  }

  Future<void> bootstrap({bool force = false}) async {
    if (_bootstrapped && !force) return;
    await refresh(force: force);
    _bootstrapped = true;
  }

  Future<void> refresh({bool force = false}) async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (info.version.trim().isNotEmpty) {
        _currentVersion = info.version.trim();
      }
    } catch (_) {
      _currentVersion = AppConfig.appVersion;
    }

    final platform = detectPlatform();
    _settings = await _fetch(platform: platform);
    _recomputeGate();
    notifyListeners();
  }

  void dismissOptionalUpdate() {
    _optionalUpdateDismissed = true;
    if (_gate == AppSettingsGate.optionalUpdate) {
      _gate = AppSettingsGate.none;
      notifyListeners();
    }
  }

  /// Soft-continue when force-update has no valid updateUrl — avoids dead-end.
  /// Session-scoped only; next refresh with a valid URL still enforces gate.
  void continueWithoutUpdateDestination() {
    _forceUpdateContinued = true;
    if (_gate == AppSettingsGate.forceUpdate) {
      _gate = AppSettingsGate.none;
      notifyListeners();
    }
  }

  /// Test/dev injection — does not hit network.
  @visibleForTesting
  void applyForTest({
    required AppClientSettings settings,
    required String currentVersion,
    bool optionalDismissed = false,
    bool forceContinued = false,
  }) {
    _settings = settings;
    _currentVersion = currentVersion;
    _optionalUpdateDismissed = optionalDismissed;
    _forceUpdateContinued = forceContinued;
    _bootstrapped = true;
    _recomputeGate();
    notifyListeners();
  }

  void _recomputeGate() {
    final resolved = resolveAppSettingsGate(
      currentVersion: _currentVersion,
      minVersion: _settings.minVersion,
      latestVersion: _settings.latestVersion,
      forceUpdate: _settings.forceUpdate,
      maintenanceMode: _settings.maintenanceMode,
    );
    if (resolved == AppSettingsGate.forceUpdate && _forceUpdateContinued) {
      // Only soft-continue when destination is still missing/invalid.
      if (_settings.validUpdateUri == null) {
        _gate = AppSettingsGate.none;
        return;
      }
      // Valid URL arrived — re-enforce force update.
      _forceUpdateContinued = false;
    }
    if (resolved == AppSettingsGate.optionalUpdate &&
        _optionalUpdateDismissed) {
      _gate = AppSettingsGate.none;
    } else {
      _gate = resolved;
    }
  }

  Future<AppClientSettings> _fetch({required String platform}) async {
    final normalized = platform.trim().toUpperCase();
    try {
      final response = await http
          .get(
            Uri.parse(
              '${AppConfig.apiBaseUrl}/app-settings?platform=$normalized',
            ),
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return AppClientSettings.safeDefaults.copyWithPlatform(normalized);
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        return AppClientSettings.safeDefaults.copyWithPlatform(normalized);
      }
      final parsed = AppClientSettings.fromJson(
        Map<String, dynamic>.from(decoded),
      );
      return AppClientSettings(
        platform: parsed.platform.isEmpty ? normalized : parsed.platform,
        minVersion: parsed.minVersion,
        latestVersion: parsed.latestVersion,
        forceUpdate: parsed.forceUpdate,
        maintenanceMode: parsed.maintenanceMode,
        maintenanceMessage: parsed.maintenanceMessage,
        supportUrl: parsed.supportUrl,
        updateUrl: parsed.updateUrl,
      );
    } catch (_) {
      return AppClientSettings.safeDefaults.copyWithPlatform(normalized);
    }
  }
}

extension on AppClientSettings {
  AppClientSettings copyWithPlatform(String platform) {
    return AppClientSettings(
      platform: platform,
      minVersion: minVersion,
      latestVersion: latestVersion,
      forceUpdate: forceUpdate,
      maintenanceMode: maintenanceMode,
      maintenanceMessage: maintenanceMessage,
      supportUrl: supportUrl,
      updateUrl: updateUrl,
    );
  }
}
