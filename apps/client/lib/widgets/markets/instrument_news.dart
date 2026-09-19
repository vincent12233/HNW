import '../../models/market_news_item.dart';
import '../../models/stock_quote.dart';

List<MarketNewsItem> newsMentioningInstrument(
  Iterable<MarketNewsItem> items,
  StockQuote stock,
) {
  final needles = <String>{
    stock.symbol.trim().toUpperCase(),
    ...stock.name
        .toUpperCase()
        .split(RegExp(r'[^A-Z0-9]+'))
        .where((part) => part.length >= 4),
  }..removeWhere((part) => part.isEmpty);
  if (needles.isEmpty) return const [];
  return items.where((item) {
    final haystack = '${item.title} ${item.source}'.toUpperCase();
    return needles.any(haystack.contains);
  }).toList();
}
