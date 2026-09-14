import 'dart:convert';

import 'package:http/http.dart' as http;

import '../app_config.dart';
import '../models/market_history.dart';
import '../models/market_news_item.dart';
import '../models/institutional_opportunity.dart';
import '../models/stock_quote.dart';
import 'auth_service.dart';
import 'local_data_cache.dart';
import '../models/company_showcase.dart';

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
  Future<List<CompanyShowcase>> fetchCompanyShowcase() async {
    try {
      final response = await http.get(Uri.parse('${AppConfig.apiBaseUrl}/company-showcase')).timeout(const Duration(seconds: 8));
      if (response.statusCode < 200 || response.statusCode >= 300) return const [];
      final decoded = jsonDecode(response.body);
      if (decoded is! List) return const [];
      return decoded.whereType<Map>().map((row) => CompanyShowcase.fromJson(Map<String, dynamic>.from(row))).toList();
    } catch (_) { return const []; }
  }
  Future<List<MarketNewsItem>> fetchMarketNews({int limit = 8}) async {
    try {
      final response = await http
          .get(
            Uri.parse('${AppConfig.apiBaseUrl}/market-data/news?limit=$limit'),
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const [];
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((row) => MarketNewsItem.fromJson(Map<String, dynamic>.from(row)))
          .where((item) => item.title.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<InstitutionalStock>> fetchInstitutionalOffers() async {
    final session = await AuthService().restoreSession();
    if (session == null) return const [];
    final response = await http
        .get(
          Uri.parse('${AppConfig.apiBaseUrl}/market-data/institutional'),
          headers: {'Authorization': 'Bearer ${session.accessToken}'},
        )
        .timeout(const Duration(seconds: 6));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return const [];
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map(
          (row) => InstitutionalStock.fromInstitutionalJson(
            Map<String, dynamic>.from(row),
          ),
        )
        .toList();
  }

  final AuthService _authService = AuthService();

  static bool acceptsRealtimeQuote(Map<String, dynamic> data) {
    final symbol = data['symbol']?.toString().trim().toUpperCase();
    final exchange = data['exchange']?.toString().trim().toUpperCase();

    if (symbol == null ||
        symbol.isEmpty ||
        exchange == null ||
        exchange.isEmpty) {
      return false;
    }

    return exchange == 'NSE' || exchange == 'BSE';
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
        queryParameters: {'symbols': normalizedSymbols, 'limit': '$limit'},
      );
      final response = await http
          .get(uri, headers: {'Authorization': 'Bearer ${session.accessToken}'})
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
    if (rows is! List ||
        json['page'] != page ||
        json['total'] is! num ||
        (json['total'] as num) < 0 ||
        json['pageSize'] is! num ||
        (json['pageSize'] as num) <= 0 ||
        json['hasMore'] is! bool) {
      throw const MarketDataException('Unable to search market data');
    }

    return MarketSearchPage(
      data: _fromRows(rows),
      total: (json['total'] as num?)?.toInt() ?? 0,
      page: (json['page'] as num?)?.toInt() ?? page,
      pageSize: (json['pageSize'] as num?)?.toInt() ?? pageSize,
      hasMore: json['hasMore'] == true,
    );
  }

  Future<MarketHistorySeries> fetchHistory({
    required String symbol,
    String exchange = 'NSE',
    String range = '1D',
  }) async {
    final normalizedSymbol = symbol.trim().toUpperCase();
    final normalizedExchange = exchange.trim().toUpperCase();
    if (normalizedExchange != 'NSE' && normalizedExchange != 'BSE') {
      throw const MarketDataException('Unsupported Indian stock exchange');
    }
    final normalizedRange = range.trim().toUpperCase();
    final cacheKey = LocalDataCache.marketHistory(
      normalizedExchange,
      normalizedSymbol,
      normalizedRange,
    );
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/market-data/history')
        .replace(
          queryParameters: {
            'symbol': normalizedSymbol,
            'exchange': normalizedExchange,
            'range': normalizedRange,
          },
        );
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw const MarketDataException('Unable to load price history');
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        throw const MarketDataException('Unable to load price history');
      }
      final json = Map<String, dynamic>.from(decoded);
      final series = MarketHistorySeries.fromJson(json);
      if (series.data.length < 2) {
        throw const MarketDataException('Unable to load price history');
      }
      await LocalDataCache.saveJson(cacheKey, {
        'cachedAt': DateTime.now().toUtc().toIso8601String(),
        'payload': json,
      });
      return series;
    } catch (_) {
      final cached = await LocalDataCache.readJson(cacheKey);
      if (cached is Map && cached['payload'] is Map) {
        final cachedAt = DateTime.tryParse(
          cached['cachedAt']?.toString() ?? '',
        );
        if (cachedAt == null ||
            DateTime.now().difference(cachedAt) >
                _historyCacheLifetime(normalizedRange)) {
          throw const MarketDataException('Unable to load price history');
        }
        return MarketHistorySeries.fromJson(
          Map<String, dynamic>.from(cached['payload'] as Map),
          delayed: true,
        );
      }
      throw const MarketDataException('Unable to load price history');
    }
  }

  Duration _historyCacheLifetime(String range) {
    if (range == '1D') return const Duration(hours: 6);
    if (range == '1W') return const Duration(days: 2);
    if (range == '1M') return const Duration(days: 7);
    if (range == '3M') return const Duration(days: 14);
    return const Duration(days: 30);
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

  Future<Map<String, dynamic>?> fetchMarketSession() async {
    try {
      final response = await http
          .get(Uri.parse('${AppConfig.apiBaseUrl}/market-data/session'))
          .timeout(const Duration(seconds: 6));
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      final decoded = jsonDecode(response.body);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (_) {
      return null;
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
      if (symbol.isEmpty || (exchange != 'NSE' && exchange != 'BSE')) continue;

      final identity = '$exchange:$symbol';
      selected.putIfAbsent(identity, () => row);
    }

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
