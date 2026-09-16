import 'package:flutter_test/flutter_test.dart';

import 'package:india_trading_app/services/app_content_service.dart';
import 'package:india_trading_app/services/insight_list_result.dart';

bool shouldUseLegacyKv({
  required bool structuredApiOk,
  required bool hasLegacyArticles,
}) {
  return !structuredApiOk && hasLegacyArticles;
}

/// Documents Insights fallback selection without network.
void main() {
  test('SUCCESS empty must not use legacy KV articles', () {
    final kv = AppContentBundle.fromJson({
      'insights': {
        'article.01': {'title': 'Legacy', 'body': 'Old'},
      },
    }).insightArticles();

    expect(
      shouldUseLegacyKv(structuredApiOk: true, hasLegacyArticles: kv.isNotEmpty),
      isFalse,
    );
  });

  test('FAILURE may fall back to legacy KV', () {
    final kv = AppContentBundle.fromJson({
      'insights': {
        'article.01': {'title': 'Legacy', 'body': 'Old'},
      },
    }).insightArticles();

    expect(
      shouldUseLegacyKv(
        structuredApiOk: false,
        hasLegacyArticles: kv.isNotEmpty,
      ),
      isTrue,
    );
    expect(kv.single.title, 'Legacy');
  });

  test('InsightListResult carries success flag', () {
    const result = InsightListResult(
      source: InsightListSource.empty,
      articles: [],
      apiSucceeded: true,
    );
    expect(result.apiSucceeded, isTrue);
    expect(result.articles, isEmpty);
  });
}
