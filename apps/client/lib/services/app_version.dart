/// Semantic version helpers for App Client Settings gates.
class AppVersion {
  const AppVersion(this.parts);

  final List<int> parts;

  /// Parses `1.2.3` / `1.10` style versions. Returns null if unusable.
  static AppVersion? tryParse(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final segments = trimmed.split('.');
    if (segments.isEmpty || segments.length > 4) return null;
    final parts = <int>[];
    for (final segment in segments) {
      if (!RegExp(r'^\d{1,4}$').hasMatch(segment)) return null;
      parts.add(int.parse(segment));
    }
    while (parts.length < 3) {
      parts.add(0);
    }
    return AppVersion(parts);
  }

  /// Negative if this < other, 0 if equal, positive if this > other.
  int compareTo(AppVersion other) {
    final len = parts.length > other.parts.length
        ? parts.length
        : other.parts.length;
    for (var i = 0; i < len; i++) {
      final a = i < parts.length ? parts[i] : 0;
      final b = i < other.parts.length ? other.parts[i] : 0;
      if (a != b) return a.compareTo(b);
    }
    return 0;
  }

  @override
  String toString() => parts.join('.');
}

enum AppSettingsGate { none, optionalUpdate, forceUpdate, maintenance }

AppSettingsGate resolveAppSettingsGate({
  required String currentVersion,
  required String minVersion,
  required String latestVersion,
  required bool forceUpdate,
  required bool maintenanceMode,
}) {
  final current = AppVersion.tryParse(currentVersion);
  final min = AppVersion.tryParse(minVersion);
  final latest = AppVersion.tryParse(latestVersion);

  // Unparseable versions must never force-lock the user.
  if (current == null) return AppSettingsGate.none;

  if (forceUpdate && min != null && current.compareTo(min) < 0) {
    return AppSettingsGate.forceUpdate;
  }
  if (maintenanceMode) {
    return AppSettingsGate.maintenance;
  }
  if (latest != null && current.compareTo(latest) < 0) {
    return AppSettingsGate.optionalUpdate;
  }
  return AppSettingsGate.none;
}
