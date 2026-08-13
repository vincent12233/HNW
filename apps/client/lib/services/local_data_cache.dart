import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class LocalDataCache {
  const LocalDataCache._();

  static const marketSnapshot = 'cache_market_snapshot';
  static const accountSnapshot = 'cache_account_snapshot';
  static const orders = 'cache_orders';
  static const withdrawals = 'cache_withdrawals';
  static const openIpos = 'cache_open_ipos';
  static const ipoApplications = 'cache_ipo_applications';

  static String marketHistory(String exchange, String symbol, String range) =>
      'cache_market_history_${exchange.toUpperCase()}_'
      '${symbol.toUpperCase()}_${range.toUpperCase()}';

  static Future<void> saveJson(String key, Object value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(key, jsonEncode(value));
  }

  static Future<dynamic> readJson(String key) async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(key);

    if (raw == null || raw.isEmpty) {
      return null;
    }

    try {
      return jsonDecode(raw);
    } catch (_) {
      await preferences.remove(key);
      return null;
    }
  }
}
