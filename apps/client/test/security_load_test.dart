import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:india_trading_app/pages/account_security_page.dart';
import 'package:india_trading_app/services/client_account_service.dart';

class PinStatusService extends ClientAccountService {
  int calls = 0;
  @override
  Future<bool> hasWithdrawalPin() async {
    if (++calls == 1) throw Exception('offline');
    return true;
  }
}

void main() {
  testWidgets('PIN status failure hides form until retry succeeds', (
    tester,
  ) async {
    final service = PinStatusService();
    await tester.pumpWidget(
      MaterialApp(
        home: AccountSecurityPage(withdrawalPin: true, accountService: service),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(TextFormField), findsNothing);
    expect(find.text('Unable to load security settings'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(service.calls, 2);
    expect(find.byType(TextFormField), findsNWidgets(4));
  });
}
