import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:india_trading_app/models/auth_session.dart';
import 'package:india_trading_app/services/auth_service.dart';
import 'package:india_trading_app/services/ipo_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('a lost IPO response retries with the same key; a confirmed next operation gets a new key', () async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await AuthService().saveSession(const AuthSession(accessToken: 'fixture', userId: 'user', phone: '9876543210', fullName: 'Test', role: 'CLIENT', accountId: 'account', accountNumber: '100'));
    final keys = <String>[];
    final client = MockClient((request) async {
      keys.add(request.headers['Idempotency-Key']!);
      if (keys.length == 1) throw TimeoutException('response lost');
      return http.Response('{"canApply":true}', 201);
    });
    await http.runWithClient(() async {
      await expectLater(IpoService().apply('ipo'), throwsA(isA<IpoException>()));
      await IpoService().apply('ipo');
      await IpoService().apply('ipo');
    }, () => client);
    expect(keys[0], keys[1]);
    expect(keys[2], isNot(keys[1]));
  });
}
