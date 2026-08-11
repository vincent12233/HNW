import 'dart:convert';

import 'package:http/http.dart' as http;

import '../app_config.dart';
import '../models/stock_quote.dart';
import 'local_data_cache.dart';

class MarketDataService {
  static final Map<String, String> _preferredExchangeBySymbol =
      <String, String>{};

  static bool acceptsRealtimeQuote(Map<String, dynamic> data) {
    final symbol = data['symbol']?.toString().trim().toUpperCase();
    final exchange = data['exchange']?.toString().trim().toUpperCase();

    if (symbol == null || symbol.isEmpty || exchange == null || exchange.isEmpty) {
      return true;
    }

    final preferred = _preferredExchangeBySymbol[symbol];
    return preferred == null || preferred == exchange;
  }

  Future<List<StockQuote>> fetchSnapshot() async {
    try {
      final response = await http
          .get(Uri.parse('${AppConfig.apiBaseUrl}/market-data'))
          .timeout(const Duration(seconds: 6));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw const MarketDataException('Unable to load market data');
      }

      final decoded = jsonDecode(response.body);

      if (decoded is! List) {
        return _cachedSnapshot();
      }

      await LocalDataCache.saveJson(LocalDataCache.marketSnapshot, decoded);

      return _fromRows(decoded);
    } catch (_) {
      return _cachedSnapshot();
    }
  }

  Future<List<StockQuote>> _cachedSnapshot() async {
    final cached = await LocalDataCache.readJson(LocalDataCache.marketSnapshot);

    if (cached is List) {
      return _fromRows(cached);
    }

    return <StockQuote>[];
  }

  List<StockQuote> _fromRows(List<dynamic> rows) {
    final selected = <String, Map<String, dynamic>>{};

    for (final item in rows) {
      final row = Map<String, dynamic>.from(item as Map);
      final symbol = row['symbol']?.toString().trim().toUpperCase() ?? '';
      final exchange = row['exchange']?.toString().trim().toUpperCase() ?? '';
      if (symbol.isEmpty) continue;

      final current = selected[symbol];
      final currentExchange =
          current?['exchange']?.toString().trim().toUpperCase() ?? '';

      if (current == null ||
          (exchange == 'NSE' && currentExchange != 'NSE')) {
        selected[symbol] = row;
      }
    }

    _preferredExchangeBySymbol
      ..clear()
      ..addEntries(
        selected.entries.map((entry) {
          final exchange =
              entry.value['exchange']?.toString().trim().toUpperCase() ?? '';
          return MapEntry(entry.key, exchange);
        }),
      );

    return selected.values
        .map(StockQuote.fromMarketDataJson)
        .where((stock) => stock.symbol.isNotEmpty && stock.price > 0)
        .toList();
  }
}

class MarketDataException implements Exception {
  const MarketDataException(this.message);

  final String message;

  @override
  String toString() => message;
}
