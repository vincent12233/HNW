import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:india_trading_app/services/watchlist_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({
      'auth_session': jsonEncode({'accessToken': 'test', 'userId': 'test'}),
    });
  });
  Future<Set<String>> fetch(String body) => http.runWithClient(
    () => WatchlistService().fetchSymbols(),
    () => MockClient((_) async => http.Response(body, 200)),
  );
  test('invalid response is not an empty watchlist', () async {
    await expectLater(fetch('{}'), throwsA(isA<WatchlistException>()));
    expect(await fetch('[]'), isEmpty);
  });
  test('same symbol on different exchanges remains separate', () async {
    expect(
      await fetch(
        jsonEncode([
          {'symbol': 'TCS', 'exchange': 'NSE'},
          {'symbol': 'TCS', 'exchange': 'BSE'},
        ]),
      ),
      {'NSE:TCS', 'BSE:TCS'},
    );
  });
}
