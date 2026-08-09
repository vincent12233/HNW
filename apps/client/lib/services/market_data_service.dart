import 'dart:convert';

import 'package:http/http.dart' as http;

import '../app_config.dart';
import '../models/stock_quote.dart';
import 'local_data_cache.dart';

class MarketDataService {
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
    return rows
        .map(
          (item) => StockQuote.fromMarketDataJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
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
