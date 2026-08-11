import 'dart:convert';

import 'package:http/http.dart' as http;

import '../app_config.dart';
import '../models/portfolio_position.dart';
import '../models/trading_order.dart';
import 'auth_service.dart';
import 'local_data_cache.dart';
import 'session_expiry_service.dart';

class TradingService {
  final AuthService _authService = AuthService();
  final SessionExpiryService _sessionExpiry = SessionExpiryService();

  Future<TradingAccountSnapshot?> fetchAccountSnapshot() async {
    final session = await _authService.restoreSession();

    if (session == null || session.accessToken.isEmpty) {
      return null;
    }

    try {
      final response = await http
          .get(
            Uri.parse('${AppConfig.apiBaseUrl}/account/portfolio'),
            headers: {'Authorization': 'Bearer ${session.accessToken}'},
          )
          .timeout(const Duration(seconds: 6));

      if (_sessionExpiry.isUnauthorized(response.statusCode)) {
        await _sessionExpiry.expire();
        return null;
      }

      final decoded = jsonDecode(response.body);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw TradingException(_apiMessage(decoded, 'Unable to load portfolio'));
      }

      if (decoded is! Map<String, dynamic>) {
        return _cachedAccountSnapshot();
      }

      await LocalDataCache.saveJson(LocalDataCache.accountSnapshot, decoded);

      return TradingAccountSnapshot.fromJson(decoded);
    } catch (_) {
      return _cachedAccountSnapshot();
    }
  }

  Future<List<TradingOrder>> fetchOrders() async {
    final session = await _authService.restoreSession();

    if (session == null || session.accessToken.isEmpty) {
      return <TradingOrder>[];
    }

    try {
      final response = await http
          .get(
            Uri.parse('${AppConfig.apiBaseUrl}/orders?pageSize=50'),
            headers: {'Authorization': 'Bearer ${session.accessToken}'},
          )
          .timeout(const Duration(seconds: 6));

      if (_sessionExpiry.isUnauthorized(response.statusCode)) {
        await _sessionExpiry.expire();
        return <TradingOrder>[];
      }

      final decoded = jsonDecode(response.body);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw TradingException(_apiMessage(decoded, 'Unable to load orders'));
      }

      final data = decoded is Map ? decoded['data'] : null;

      if (data is! List) {
        return _cachedOrders();
      }

      await LocalDataCache.saveJson(LocalDataCache.orders, data);

      return _ordersFromRows(data);
    } catch (_) {
      return _cachedOrders();
    }
  }

  Future<TradingOrder> placeMarketOrder(TradingOrder order) async {
    final session = await _authService.restoreSession();

    if (session == null || session.accessToken.isEmpty) {
      throw const TradingException('Please sign in again');
    }

    final response = await http
        .post(
          Uri.parse('${AppConfig.apiBaseUrl}/orders'),
          headers: {
            'Authorization': 'Bearer ${session.accessToken}',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'clientOrderId':
                'APP-${DateTime.now().microsecondsSinceEpoch}-${order.symbol}',
            'exchange': 'NSE',
            'symbol': order.symbol,
            'side': order.isBuy ? 'BUY' : 'SELL',
            'type': 'MARKET',
            'timeInForce': 'DAY',
            'quantity': order.quantity,
          }),
        )
        .timeout(const Duration(seconds: 10));

    if (_sessionExpiry.isUnauthorized(response.statusCode)) {
      await _sessionExpiry.expire();
      throw const TradingException('Please sign in again');
    }

    final decoded = jsonDecode(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw TradingException(_apiMessage(decoded, 'Order placement failed'));
    }

    final apiOrder = decoded is Map ? decoded['order'] : null;

    if (apiOrder is! Map) {
      return order;
    }

    return TradingOrder.fromApiJson(Map<String, dynamic>.from(apiOrder));
  }
}

Future<TradingAccountSnapshot?> _cachedAccountSnapshot() async {
  final cached = await LocalDataCache.readJson(LocalDataCache.accountSnapshot);

  if (cached is Map) {
    return TradingAccountSnapshot.fromJson(Map<String, dynamic>.from(cached));
  }

  return null;
}

Future<List<TradingOrder>> _cachedOrders() async {
  final cached = await LocalDataCache.readJson(LocalDataCache.orders);

  if (cached is List) {
    return _ordersFromRows(cached);
  }

  return <TradingOrder>[];
}

List<TradingOrder> _ordersFromRows(List<dynamic> rows) {
  return rows
      .map(
        (item) =>
            TradingOrder.fromApiJson(Map<String, dynamic>.from(item as Map)),
      )
      .toList();
}

class TradingAccountSnapshot {
  const TradingAccountSnapshot({
    required this.cashBalance,
    required this.realizedProfitLoss,
    required this.positions,
  });

  final double cashBalance;
  final double realizedProfitLoss;
  final List<PortfolioPosition> positions;

  factory TradingAccountSnapshot.fromJson(Map<String, dynamic> json) {
    final balances = (json['balances'] as Map?)?.cast<String, dynamic>() ?? {};
    final pnl = (json['pnl'] as Map?)?.cast<String, dynamic>() ?? {};
    final positionRows = json['positions'];

    return TradingAccountSnapshot(
      cashBalance: _doubleValue(balances['cashBalance']),
      realizedProfitLoss: _doubleValue(pnl['realizedPnl']),
      positions: positionRows is List
          ? positionRows
                .map(
                  (item) => PortfolioPosition.fromApiJson(
                    Map<String, dynamic>.from(item as Map),
                  ),
                )
                .toList()
          : <PortfolioPosition>[],
    );
  }
}

class TradingException implements Exception {
  const TradingException(this.message);

  final String message;

  @override
  String toString() => message;
}

String _apiMessage(dynamic decoded, String fallback) {
  if (decoded is Map) {
    final message = decoded['message'];

    if (message is List && message.isNotEmpty) {
      return message.first.toString();
    }

    if (message != null) {
      return message.toString();
    }
  }

  return fallback;
}

double _doubleValue(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }

  return double.tryParse(value?.toString() ?? '') ?? 0;
}
