import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:india_trading_app/models/market_news_item.dart';
import 'package:india_trading_app/pages/market_news_page.dart';

void main() {
  final article = MarketNewsItem(
    id: 'a',
    title: 'Market update',
    source: 'Source',
    url: 'https://example.com',
    publishedAt: DateTime(2026),
  );
  testWidgets('empty news can be retried', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MarketNewsPage(
          items: const [],
          onOpen: (_) async {},
          onRefresh: () async => [article],
        ),
      ),
    );
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Market update'), findsOneWidget);
  });
  testWidgets('failed refresh retains articles and displays warning', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MarketNewsPage(
          items: [article],
          onOpen: (_) async {},
          onRefresh: () async => throw Exception('offline'),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Refresh'));
    await tester.pumpAndSettle();
    expect(find.text('Market update'), findsOneWidget);
    expect(
      find.text('News could not be updated. Please try again.'),
      findsOneWidget,
    );
  });
}
