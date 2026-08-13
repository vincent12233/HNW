import 'dart:convert';

import 'package:http/http.dart' as http;

import '../app_config.dart';
import '../models/portfolio_position.dart';
import '../models/account_transaction.dart';
import '../models/trading_order.dart';
import 'auth_service.dart';
import 'local_data_cache.dart';
import 'session_expiry_service.dart';

class TradingService {
  final AuthService _authService = AuthService();
  final SessionExpiryService _sessionExpiry = SessionExpiryService();

  static TradingOrder? _lastPlacedOrder;

  static void clearLastPlacedOrder() {
    _lastPlacedOrder = null;
  }

  static TradingOrder? takeLastPlacedOrder() {
    final order = _lastPlacedOrder;
    _lastPlacedOrder = null;
    return order;
  }

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
        throw TradingException(
          _apiMessage(decoded, 'Unable to load portfolio'),
        );
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

  Future<List<AccountTransaction>> fetchTransactions() async {
    final session = await _authService.restoreSession();
    if (session == null || session.accessToken.isEmpty) return const [];
    final response = await http
        .get(
          Uri.parse(
            '${AppConfig.apiBaseUrl}/account/transactions?pageSize=100',
          ),
          headers: {'Authorization': 'Bearer ${session.accessToken}'},
        )
        .timeout(const Duration(seconds: 6));
    if (_sessionExpiry.isUnauthorized(response.statusCode)) {
      await _sessionExpiry.expire();
      return const [];
    }
    final decoded = jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw TradingException(
        _apiMessage(decoded, 'Unable to load transactions'),
      );
    }
    final rows = decoded is Map ? decoded['data'] : null;
    if (rows is! List) return const [];
    return rows
        .whereType<Map>()
        .map(
          (row) => AccountTransaction.fromJson(Map<String, dynamic>.from(row)),
        )
        .toList();
  }

  Future<TradingOrder> placeOrder(TradingOrder order) async {
    final session = await _authService.restoreSession();

    if (session == null || session.accessToken.isEmpty) {
      throw const TradingException('Please sign in again');
    }

    final body = <String, dynamic>{
      'clientOrderId':
          'APP-${DateTime.now().microsecondsSinceEpoch}-${order.exchange}-${order.symbol}',
      'exchange': order.exchange,
      'symbol': order.symbol,
      'side': order.isBuy ? 'BUY' : 'SELL',
      'type': order.type,
      'timeInForce': order.timeInForce,
      'quantity': order.quantity,
    };
    if (order.isLimit && order.limitPrice != null) {
      body['limitPrice'] = order.limitPrice!.toStringAsFixed(4);
    }

    final response = await http
        .post(
          Uri.parse('${AppConfig.apiBaseUrl}/orders'),
          headers: {
            'Authorization': 'Bearer ${session.accessToken}',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
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
    final confirmedOrder = apiOrder is Map
        ? TradingOrder.fromApiJson(Map<String, dynamic>.from(apiOrder))
        : order;

    _lastPlacedOrder = confirmedOrder;
    return confirmedOrder;
  }

  Future<TradingOrder> placeMarketOrder(TradingOrder order) {
    return placeOrder(order);
  }

  Future<void> cancelOrder(String orderId) async {
    final session = await _authService.restoreSession();
    if (session == null || session.accessToken.isEmpty) {
      throw const TradingException('Please sign in again');
    }

    final response = await http
        .post(
          Uri.parse('${AppConfig.apiBaseUrl}/orders/$orderId/cancel'),
          headers: {'Authorization': 'Bearer ${session.accessToken}'},
        )
        .timeout(const Duration(seconds: 10));

    if (_sessionExpiry.isUnauthorized(response.statusCode)) {
      await _sessionExpiry.expire();
      throw const TradingException('Please sign in again');
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      decoded = null;
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw TradingException(_apiMessage(decoded, 'Order cancellation failed'));
    }
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
    required this.buyingPower,
    required this.frozenBalance,
    required this.realizedProfitLoss,
    required this.positions,
  });

  final double cashBalance;
  final double buyingPower;
  final double frozenBalance;
  final double realizedProfitLoss;
  final List<PortfolioPosition> positions;

  factory TradingAccountSnapshot.fromJson(Map<String, dynamic> json) {
    final balances = (json['balances'] as Map?)?.cast<String, dynamic>() ?? {};
    final pnl = (json['pnl'] as Map?)?.cast<String, dynamic>() ?? {};
    final positionRows = json['positions'];

    return TradingAccountSnapshot(
      cashBalance: _doubleValue(balances['cashBalance']),
      buyingPower: _doubleValue(
        balances['buyingPower'] ?? balances['cashBalance'],
      ),
      frozenBalance: _doubleValue(balances['frozenBalance']),
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
