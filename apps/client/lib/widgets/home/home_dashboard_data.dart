import '../../models/stock_quote.dart';

class HomeIndexQuote {
  const HomeIndexQuote({
    required this.label,
    required this.price,
    required this.changePercent,
  });

  final String label;
  final double price;
  final double changePercent;

  bool get available => price > 0 && price.isFinite && changePercent.isFinite;
}

enum HomeKycTodo { hidden, pending, rejected, unavailable }

HomeKycTodo homeKycTodo(String status, {required bool available}) {
  if (!available) return HomeKycTodo.hidden;
  switch (status) {
    case 'PENDING':
      return HomeKycTodo.pending;
    case 'REJECTED':
      return HomeKycTodo.rejected;
    case 'APPROVED':
      return HomeKycTodo.hidden;
    default:
      return HomeKycTodo.unavailable;
  }
}

List<StockQuote> homeTopMovers(
  Iterable<StockQuote> stocks, {
  required bool gainers,
  int limit = 3,
}) {
  final movers = stocks
      .where(
        (stock) =>
            stock.price > 0 &&
            stock.change.isFinite &&
            (gainers ? stock.change > 0 : stock.change < 0),
      )
      .toList();
  movers.sort(
    (left, right) => gainers
        ? right.change.compareTo(left.change)
        : left.change.compareTo(right.change),
  );
  return movers.take(limit).toList();
}

DateTime? latestQuoteUpdatedAt(Iterable<StockQuote> quotes) {
  DateTime? latest;
  for (final quote in quotes) {
    if (quote.price <= 0) continue;
    if (quote.updatedAt.millisecondsSinceEpoch <= 0) continue;
    if (latest == null || quote.updatedAt.isAfter(latest)) {
      latest = quote.updatedAt;
    }
  }
  return latest;
}

bool quotesAreStale(
  Iterable<StockQuote> quotes, {
  DateTime? now,
  Duration maxAge = const Duration(minutes: 2),
}) {
  final latest = latestQuoteUpdatedAt(quotes);
  if (latest == null) {
    return quotes.any((quote) => quote.price > 0 && !quote.quoteFresh);
  }
  return (now ?? DateTime.now()).difference(latest) > maxAge ||
      quotes.any((quote) => quote.price > 0 && !quote.quoteFresh);
}

String homeRelativeTime(DateTime at, {DateTime? now}) {
  final difference = (now ?? DateTime.now()).difference(at);
  if (difference.inMinutes < 1) return 'Just now';
  if (difference.inHours < 1) return '${difference.inMinutes}m ago';
  if (difference.inDays < 1) return '${difference.inHours}h ago';
  return '${difference.inDays}d ago';
}

String homeQuoteFreshnessLabel({
  required DateTime? updatedAt,
  required bool quotesConnected,
  required bool stale,
  DateTime? now,
}) {
  if (!quotesConnected) {
    return 'Live quotes reconnecting. Prices may be delayed.';
  }
  if (updatedAt == null || updatedAt.millisecondsSinceEpoch <= 0) {
    return stale ? 'Quote time unavailable' : 'Quotes updating';
  }
  final age = homeRelativeTime(updatedAt, now: now);
  if (stale) return 'Quotes delayed · updated $age';
  return 'Updated $age';
}
