import 'package:flutter_test/flutter_test.dart';
import 'package:india_trading_app/models/auth_session.dart';
import 'package:india_trading_app/services/salesmartly_service.dart';

void main() {
  const session = AuthSession(
    accessToken: 'access-secret',
    refreshToken: 'refresh-secret',
    userId: '4be671af-2cd8-4ce9-b4b6-99ddc99133af',
    phone: '+919876543210',
    fullName: 'Sensitive Customer Name',
    role: 'CLIENT',
    accountId: 'account-secret',
    accountNumber: '998877665544',
  );

  test('SaleSmartly receives only a stable pseudonymous customer identity', () {
    final identity = SaleSmartlyService.identityFor(session);

    expect(identity.customerReference, startsWith('hnw_'));
    expect(identity.customerReference, hasLength(28));
    expect(identity.displayName, startsWith('HNW customer '));
    final serialized = '${identity.customerReference} ${identity.displayName}';
    for (final secret in <String>[
      session.userId,
      session.phone,
      session.fullName,
      session.accountId,
      session.accountNumber,
      session.accessToken,
      session.refreshToken!,
    ]) {
      expect(serialized, isNot(contains(secret)));
    }
  });

  test('same customer maps consistently while different customers do not', () {
    final first = SaleSmartlyService.identityFor(session);
    final again = SaleSmartlyService.identityFor(session);
    final other = SaleSmartlyService.identityFor(
      const AuthSession(
        accessToken: 'different',
        userId: 'different-user',
        phone: '+911111111111',
        fullName: 'Another Customer',
        role: 'CLIENT',
        accountId: 'different-account',
        accountNumber: '111111111111',
      ),
    );

    expect(again.customerReference, first.customerReference);
    expect(other.customerReference, isNot(first.customerReference));
  });

  test('script snippets still normalize without exposing configuration', () {
    expect(
      SaleSmartlyService.normalizeScriptUrl(
        '<script src="https://assets.example/project.js"></script>',
      ),
      'https://assets.example/project.js',
    );
  });
}
