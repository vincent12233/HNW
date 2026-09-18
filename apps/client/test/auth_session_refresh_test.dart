import 'package:flutter_test/flutter_test.dart';
import 'package:india_trading_app/models/auth_session.dart';

void main() {
  test('stores refresh token from login payload in secure-session JSON', () {
    final session = AuthSession.fromLoginJson({
      'accessToken': 'access-1',
      'refreshToken': 'refresh-1',
      'user': {
        'id': 'u1',
        'phone': '9876543210',
        'fullName': 'Test User',
        'role': 'CLIENT',
      },
      'account': {'id': 'a1', 'accountNumber': 'HNW1'},
    });

    expect(session.refreshToken, 'refresh-1');
    expect(session.toJson()['refreshToken'], 'refresh-1');
    expect(AuthSession.fromJson(session.toJson()).refreshToken, 'refresh-1');
  });
}
