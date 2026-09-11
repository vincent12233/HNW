import 'market_data_service.dart';

/// Skip a bounded number of pages with no eligible logo addresses.
/// Actual image failures are still handled by the browsing widgets.
Future<MarketSearchPage> loadLogoMarketPage({
  required int page,
  required Future<MarketSearchPage> Function(int) fetch,
  required Set<String> failedUrls,
  required bool Function() isCurrent,
}) async {
  for (var attempt = 0; ; attempt++) {
    final result = await fetch(page);
    if (result.page != page) {
      throw StateError('Market pagination returned an unexpected page');
    }
    final eligible = result.data
        .where(
          (stock) =>
              stock.logoUrl?.trim().isNotEmpty == true &&
              !failedUrls.contains(stock.logoUrl),
        )
        .toList();
    if (!isCurrent() ||
        eligible.isNotEmpty ||
        !result.hasMore ||
        attempt >= 2) {
      return MarketSearchPage(
        data: eligible,
        total: result.total,
        page: result.page,
        pageSize: result.pageSize,
        hasMore: result.hasMore,
      );
    }
    page = result.page + 1;
  }
}
