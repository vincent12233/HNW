import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:india_trading_app/pages/account_settings_page.dart';
import 'package:india_trading_app/services/client_account_service.dart';

class DelayedProfile extends ClientAccountService {
  final result = Completer<Map<String, dynamic>>();
  @override
  Future<Map<String, dynamic>> profile() => result.future;
}

void main() {
  testWidgets(
    'leaving during profile load does not access a disposed controller',
    (tester) async {
      final service = DelayedProfile();
      await tester.pumpWidget(
        MaterialApp(
          home: AccountSettingsPage(
            section: 'profile',
            accountService: service,
          ),
        ),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      service.result.complete({'fullName': 'Test Client'});
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('profile exposes only editable name and read-only account ID', (
    tester,
  ) async {
    final service = DelayedProfile();
    service.result.complete({
      'fullName': 'Test Client',
      'email': 'hidden@example.com',
      'account': {'accountNumber': 'ACCOUNT-123'},
    });
    await tester.pumpWidget(
      MaterialApp(
        home: AccountSettingsPage(section: 'profile', accountService: service),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('ACCOUNT-123'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('hidden@example.com'), findsNothing);
  });
}
