import 'dart:convert';

import 'package:http/http.dart' as http;

import '../app_config.dart';
import 'auth_service.dart';
import 'session_expiry_service.dart';

class WatchlistService {
  final AuthService _auth = AuthService();
  final SessionExpiryService _sessionExpiry = SessionExpiryService();

  static String key(String exchange, String symbol) =>
      '${exchange.trim().toUpperCase()}:${symbol.trim().toUpperCase()}';

  Future<Set<String>> fetchSymbols() async {
    final session = await _auth.restoreSession();
    if (session == null || session.accessToken.isEmpty) return <String>{};

    final response = await http
        .get(
          Uri.parse('${AppConfig.apiBaseUrl}/watchlist'),
          headers: {'Authorization': 'Bearer ${session.accessToken}'},
        )
        .timeout(const Duration(seconds: 6));

    if (_sessionExpiry.isUnauthorized(response.statusCode)) {
      await _sessionExpiry.expire();
      return <String>{};
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const WatchlistException('Unable to load watchlist');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw const WatchlistException('Unable to load watchlist');
    }
    return decoded
        .whereType<Map>()
        .map((item) {
          final symbol = item['symbol']?.toString() ?? '';
          final exchange = item['exchange']?.toString() ?? 'NSE';
          return symbol.trim().isEmpty ? '' : key(exchange, symbol);
        })
        .where((value) => value.isNotEmpty)
        .toSet();
  }

  Future<void> add(String symbol, {String exchange = 'NSE'}) async {
    await _change(method: 'POST', symbol: symbol, exchange: exchange);
  }

  Future<void> remove(String symbol, {String exchange = 'NSE'}) async {
    await _change(method: 'DELETE', symbol: symbol, exchange: exchange);
  }

  Future<void> _change({
    required String method,
    required String symbol,
    required String exchange,
  }) async {
    final session = await _auth.restoreSession();
    if (session == null || session.accessToken.isEmpty) {
      throw const WatchlistException('Please sign in again');
    }

    final normalized = symbol.trim().toUpperCase();
    late final http.Response response;
    if (method == 'POST') {
      response = await http
          .post(
            Uri.parse('${AppConfig.apiBaseUrl}/watchlist'),
            headers: {
              'Authorization': 'Bearer ${session.accessToken}',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'symbol': normalized, 'exchange': exchange}),
          )
          .timeout(const Duration(seconds: 6));
    } else {
      final uri = Uri.parse(
        '${AppConfig.apiBaseUrl}/watchlist/$normalized',
      ).replace(queryParameters: {'exchange': exchange});
      response = await http
          .delete(
            uri,
            headers: {'Authorization': 'Bearer ${session.accessToken}'},
          )
          .timeout(const Duration(seconds: 6));
    }

    if (_sessionExpiry.isUnauthorized(response.statusCode)) {
      await _sessionExpiry.expire();
      throw const WatchlistException('Please sign in again');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const WatchlistException('Unable to update watchlist');
    }
  }
}

class WatchlistException implements Exception {
  const WatchlistException(this.message);

  final String message;

  @override
  String toString() => message;
}
