import 'dart:convert';

import 'package:http/http.dart' as http;

import '../app_config.dart';
import '../models/stock_quote.dart';

/// Loads CMS-configured featured instruments from the public market catalog.
class FeaturedInstrumentsService {
  FeaturedInstrumentsService._();

  static final FeaturedInstrumentsService instance =
      FeaturedInstrumentsService._();

  Future<List<StockQuote>> homeFeatured({int limit = 20}) {
    return _fetch(featuredHome: true, limit: limit);
  }

  Future<List<StockQuote>> marketsFeatured({int limit = 20}) {
    return _fetch(featuredMarkets: true, limit: limit);
  }

  Future<List<StockQuote>> _fetch({
    bool? featuredHome,
    bool? featuredMarkets,
    int limit = 20,
  }) async {
    try {
      final params = <String, String>{
        'type': 'EQUITY',
        'limit': '$limit',
        if (featuredHome == true) 'featuredHome': 'true',
        if (featuredMarkets == true) 'featuredMarkets': 'true',
      };
      final uri = Uri.parse(
        '${AppConfig.apiBaseUrl}/market/instruments',
      ).replace(queryParameters: params);
      final response = await http.get(uri).timeout(const Duration(seconds: 12));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const [];
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return const [];
      final data = decoded['data'];
      if (data is! List) return const [];
      return data
          .whereType<Map>()
          .map((row) => _toQuote(Map<String, dynamic>.from(row)))
          .whereType<StockQuote>()
          .toList();
    } catch (_) {
      return const [];
    }
  }

  StockQuote? _toQuote(Map<String, dynamic> json) {
    final symbol = json['symbol']?.toString() ?? '';
    if (symbol.isEmpty) return null;
    final quote = json['quote'];
    final quoteMap = quote is Map
        ? Map<String, dynamic>.from(quote)
        : <String, dynamic>{};
    final price = _double(quoteMap['lastPrice']) ?? _double(json['price']) ?? 0;
    final previousClose = _double(quoteMap['previousClose']);
    final change = previousClose != null && previousClose > 0 && price > 0
        ? ((price - previousClose) / previousClose) * 100
        : 0.0;
    final asOf =
        DateTime.tryParse('${quoteMap['asOf'] ?? ''}') ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    final quoteFresh =
        DateTime.now().difference(asOf) <= const Duration(minutes: 2);

    return StockQuote(
      symbol,
      json['name']?.toString() ?? '',
      price,
      change,
      _int(quoteMap['volume']),
      asOf,
      logoUrl: json['logoUrl']?.toString(),
      category: json['category']?.toString(),
      quoteFresh: price > 0 && quoteFresh,
      previousClose: previousClose,
      open: _double(quoteMap['openPrice']),
      high: _double(quoteMap['highPrice']),
      low: _double(quoteMap['lowPrice']),
      bid: _double(quoteMap['bidPrice']),
      ask: _double(quoteMap['askPrice']),
      exchange: json['exchange']?.toString() ?? 'NSE',
    );
  }

  static double? _double(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  static int _int(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
