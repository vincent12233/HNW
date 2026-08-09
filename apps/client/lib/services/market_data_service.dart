import 'dart:convert';

import 'package:http/http.dart' as http;

import '../app_config.dart';
import '../models/stock_quote.dart';

class MarketDataService {
  Future<List<StockQuote>> fetchSnapshot() async {
    final response = await http
        .get(Uri.parse('${AppConfig.apiBaseUrl}/market-data'))
        .timeout(const Duration(seconds: 6));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const MarketDataException('Unable to load market data');
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! List) {
      return <StockQuote>[];
    }

    return decoded
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
