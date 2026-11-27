import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

/// Non-secret operation identity, scoped to an authenticated account and IPO.
/// Persist before sending and clear only after a confirmed response.
class PendingIpoOperation {
  static final Map<String, Future<String>> _creating = {};
  static String _key(String accountId, String ipoId) =>
      'pending_ipo:$accountId:$ipoId';

  static Future<String> begin(String accountId, String ipoId) {
    final key = _key(accountId, ipoId);
    return _creating.putIfAbsent(key, () async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final saved = prefs.getString(key);
        if (saved != null) return saved;
        final random = Random.secure();
        final value = List.generate(24, (_) => random.nextInt(256)
            .toRadixString(16).padLeft(2, '0')).join();
        if (!await prefs.setString(key, value)) {
          throw StateError('Could not persist IPO request identity');
        }
        return value;
      } finally {
        _creating.remove(key);
      }
    });
  }

  static Future<void> complete(String accountId, String ipoId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(accountId, ipoId));
  }
}
