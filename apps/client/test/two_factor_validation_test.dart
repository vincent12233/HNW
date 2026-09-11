import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:india_trading_app/pages/two_factor_page.dart';
import 'package:india_trading_app/services/client_account_service.dart';

class TwoFactorFake extends ClientAccountService {
  @override
  Future<Map<String, dynamic>> twoFactorStatus() async => {'enabled': true};
}

void main() {
  testWidgets('empty password and code are validated before disabling', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: TwoFactorPage(accountService: TwoFactorFake())),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Disable'));
    await tester.pump();
    expect(find.text('Enter your current login password'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'test-password');
    await tester.tap(find.text('Disable'));
    await tester.pump();
    expect(
      find.text('Enter an authenticator or recovery code'),
      findsOneWidget,
    );
    await tester.enterText(find.byType(TextField).last, 'ABCD-EFGH');
    expect(
      tester.widget<TextField>(find.byType(TextField).last).controller!.text,
      'ABCD-EFGH',
    );
  });
}
