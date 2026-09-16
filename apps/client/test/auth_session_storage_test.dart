import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:india_trading_app/models/auth_session.dart';
import 'package:india_trading_app/services/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('saveSession keeps access token out of SharedPreferences', () async {
    const session = AuthSession(
      accessToken: 'secret-token',
      userId: 'user-1',
      phone: '9876543210',
      fullName: 'Demo Client',
      role: 'CLIENT',
      accountId: 'acc-1',
      accountNumber: '100001',
    );

    await AuthService().saveSession(session);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('auth_session'), isNull);
    expect(prefs.getString('account_name'), 'Demo Client');
    expect(prefs.getString('account_phone'), '9876543210');

    final restored = await AuthService().restoreSession();
    expect(restored, isNotNull);
    expect(restored!.accessToken, 'secret-token');
    expect(restored.fullName, 'Demo Client');
  });

  test(
    'restoreSession migrates legacy plaintext prefs then scrubs them',
    () async {
      const encoded =
          '{"accessToken":"legacy-token","userId":"user-2","phone":"9000000000","fullName":"Legacy","role":"CLIENT","accountId":"acc-2","accountNumber":"100002"}';
      SharedPreferences.setMockInitialValues({'auth_session': encoded});
      FlutterSecureStorage.setMockInitialValues({});

      final restored = await AuthService().restoreSession();
      expect(restored, isNotNull);
      expect(restored!.accessToken, 'legacy-token');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('auth_session'), isNull);
    },
  );
}
