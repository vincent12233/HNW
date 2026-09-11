import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:india_trading_app/services/trading_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({
      'auth_session': jsonEncode({
        'accessToken': 'test-token',
        'userId': 'test-user',
      }),
    });
  });
  Future<void> cancelWith(String body, {int status = 200}) =>
      http.runWithClient(
        () => TradingService().cancelOrder('order-1'),
        () => MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, endsWith('/orders/order-1/cancel'));
          return http.Response(body, status);
        }),
      );

  test('accepts confirmed cancellation of the requested order', () async {
    await cancelWith(
      jsonEncode({
        'cancelled': true,
        'order': {'id': 'order-1', 'status': 'CANCELLED'},
      }),
    );
  });
  test('HTTP success alone cannot confirm cancellation', () async {
    for (final body in [
      '',
      '<html>proxy</html>',
      '{}',
      jsonEncode({
        'cancelled': false,
        'order': {'id': 'order-1', 'status': 'CANCELLED'},
      }),
      jsonEncode({
        'cancelled': true,
        'order': {'id': 'other', 'status': 'CANCELLED'},
      }),
      jsonEncode({
        'cancelled': true,
        'order': {'id': 'order-1', 'status': 'FILLED'},
      }),
    ]) {
      await expectLater(cancelWith(body), throwsA(isA<TradingException>()));
    }
  });
  test(
    'network failure explains that the final status needs checking',
    () async {
      await http.runWithClient(() async {
        await expectLater(
          TradingService().cancelOrder('order-1'),
          throwsA(
            isA<TradingException>().having(
              (e) => e.message,
              'message',
              contains('Refresh your orders'),
            ),
          ),
        );
      }, () => MockClient((_) async => throw http.ClientException('offline')));
    },
  );
  test('backend rejection remains an error', () async {
    await expectLater(
      cancelWith('{"message":"Order already filled"}', status: 400),
      throwsA(
        isA<TradingException>().having(
          (e) => e.message,
          'message',
          'Order already filled',
        ),
      ),
    );
  });
}
