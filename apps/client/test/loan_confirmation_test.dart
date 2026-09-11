import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:india_trading_app/services/client_account_service.dart';
import 'package:india_trading_app/services/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({
      'auth_session': jsonEncode({'accessToken': 'test', 'userId': 'test'}),
    });
  });
  Future<void> apply(Object response) => http.runWithClient(
    () => ClientAccountService().applyForLoan(),
    () => MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, endsWith('/loans/apply'));
      expect(jsonDecode(request.body), isEmpty);
      return http.Response(jsonEncode(response), 200);
    }),
  );
  test(
    'only a valid pending application confirms submission without amount',
    () async {
      await apply({'id': 'loan', 'status': 'PENDING'});
      for (final response in [
        {},
        {'id': '', 'status': 'PENDING'},
        {'id': 'loan', 'status': 'REJECTED'},
      ]) {
        await expectLater(apply(response), throwsA(isA<AuthException>()));
      }
    },
  );
}
