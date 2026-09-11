import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:india_trading_app/services/market_data_service.dart';

void main() {
  Future<MarketSearchPage> search(Map<String, dynamic> body) =>
      http.runWithClient(
        () => MarketDataService().searchSnapshot(page: 2),
        () => MockClient((_) async => http.Response(jsonEncode(body), 200)),
      );
  Map<String, dynamic> response() => {
    'data': [],
    'page': 2,
    'pageSize': 50,
    'total': 100,
    'hasMore': false,
  };
  test(
    'malformed or repeated pages are errors rather than empty results',
    () async {
      for (final body in [
        <String, dynamic>{},
        {...response(), 'data': null},
        {...response(), 'page': 1},
        {...response(), 'hasMore': 'true'},
      ]) {
        await expectLater(search(body), throwsA(isA<MarketDataException>()));
      }
    },
  );
  test('valid empty page remains a valid result', () async {
    expect((await search(response())).data, isEmpty);
  });
  test('same symbol on NSE and BSE remains two instruments', () async {
    final result = await search({
      ...response(),
      'data': [
        {'symbol': 'TCS', 'exchange': 'NSE', 'lastPrice': 100, 'price': 100},
        {'symbol': 'TCS', 'exchange': 'BSE', 'lastPrice': 101, 'price': 101},
      ],
    });
    expect(result.data.map((s) => '${s.exchange}:${s.symbol}').toSet(), {
      'NSE:TCS',
      'BSE:TCS',
    });
  });
}
