import 'package:flutter_test/flutter_test.dart';
import 'package:india_trading_app/services/logo_market_page.dart';
import 'package:india_trading_app/services/market_data_service.dart';

void main() {
  test(
    'empty pages are bounded to three requests and preserve next page',
    () async {
      final calls = <int>[];
      final result = await loadLogoMarketPage(
        page: 1,
        failedUrls: {},
        isCurrent: () => true,
        fetch: (page) async {
          calls.add(page);
          return MarketSearchPage(
            data: [],
            total: 1000,
            page: page,
            pageSize: 50,
            hasMore: true,
          );
        },
      );
      expect(calls, [1, 2, 3]);
      expect(result.page, 3);
      expect(result.hasMore, isTrue);
    },
  );
  test('end of catalog does not fetch another page', () async {
    var calls = 0;
    final result = await loadLogoMarketPage(
      page: 1,
      failedUrls: {},
      isCurrent: () => true,
      fetch: (page) async {
        calls++;
        return MarketSearchPage(
          data: [],
          total: 0,
          page: page,
          pageSize: 50,
          hasMore: false,
        );
      },
    );
    expect(calls, 1);
    expect(result.hasMore, isFalse);
  });
}
