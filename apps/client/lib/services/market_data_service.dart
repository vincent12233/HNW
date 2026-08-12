import 'dart:convert';

import 'package:http/http.dart' as http;

import '../app_config.dart';
import '../models/stock_quote.dart';
import 'auth_service.dart';
import 'local_data_cache.dart';

class MarketSearchPage {
  const MarketSearchPage({
    required this.data,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.hasMore,
  });

  final List<StockQuote> data;
  final int total;
  final int page;
  final int pageSize;
  final bool hasMore;
}

class MarketDataService {
  final AuthService _authService = AuthService();

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
    return fetchHomeBootstrap();
  }

  Future<List<StockQuote>> fetchHomeBootstrap({
    Iterable<String> symbols = const <String>[],
    int limit = 40,
  }) async {
    try {
      final session = await _authService.restoreSession();
      if (session == null || session.accessToken.isEmpty) {
        return _cachedSnapshot();
      }

      final normalizedSymbols = symbols
          .map((symbol) => symbol.trim().toUpperCase())
          .where((symbol) => symbol.isNotEmpty)
          .toSet()
          .join(',');
      final uri = Uri.parse('${AppConfig.apiBaseUrl}/market-data/home').replace(
        queryParameters: {
          'symbols': normalizedSymbols,
          'limit': '$limit',
        },
      );
      final response = await http
          .get(
            uri,
            headers: {'Authorization': 'Bearer ${session.accessToken}'},
          )
          .timeout(const Duration(seconds: 6));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw const MarketDataException('Unable to load home market data');
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

  Future<MarketSearchPage> searchSnapshot({
    String query = '',
    int page = 1,
    int pageSize = 50,
  }) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/market-data/search').replace(
      queryParameters: {
        'q': query.trim(),
        'page': '$page',
        'pageSize': '$pageSize',
      },
    );
    final response = await http.get(uri).timeout(const Duration(seconds: 6));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const MarketDataException('Unable to search market data');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const MarketDataException('Unable to search market data');
    }
    final json = Map<String, dynamic>.from(decoded);
    final rows = json['data'];

    return MarketSearchPage(
      data: rows is List ? _fromRows(rows) : <StockQuote>[],
      total: (json['total'] as num?)?.toInt() ?? 0,
      page: (json['page'] as num?)?.toInt() ?? page,
      pageSize: (json['pageSize'] as num?)?.toInt() ?? pageSize,
      hasMore: json['hasMore'] == true,
    );
  }

  Future<List<Map<String, dynamic>>> fetchIndexSnapshot() async {
    try {
      final response = await http
          .get(Uri.parse('${AppConfig.apiBaseUrl}/market-data/indices'))
          .timeout(const Duration(seconds: 6));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return <Map<String, dynamic>>[];
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! List) return <Map<String, dynamic>>[];

      return decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .where((item) => item['symbol']?.toString().isNotEmpty == true)
          .toList();
    } catch (_) {
      return <Map<String, dynamic>>[];
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

    final stocks = selected.values
        .map(StockQuote.fromMarketDataJson)
        .where((stock) => stock.symbol.isNotEmpty && stock.price > 0)
        .toList();

    stocks.sort((left, right) {
      final freshnessDifference =
          (right.quoteFresh ? 1 : 0) - (left.quoteFresh ? 1 : 0);
      if (freshnessDifference != 0) return freshnessDifference;
      return 0;
    });

    return stocks;
  }
}

class MarketDataException implements Exception {
  const MarketDataException(this.message);

  final String message;

  @override
  String toString() => message;
}
