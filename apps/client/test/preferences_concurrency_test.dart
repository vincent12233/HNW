import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:india_trading_app/pages/account_settings_page.dart';
import 'package:india_trading_app/services/client_account_service.dart';

class PreferenceService extends ClientAccountService {
  final requests = <String, Completer<void>>{};
  @override
  Future<Map<String, dynamic>> preferences() async => {
    'orderNotifications': false,
    'accountNotifications': false,
    'supportNotifications': false,
  };
  @override
  Future<void> updatePreferences(Map<String, dynamic> data) {
    final request = Completer<void>();
    requests[data.keys.single] = request;
    return request.future;
  }
}

void main() {
  testWidgets('out-of-order preference saves preserve both changes', (
    tester,
  ) async {
    final service = PreferenceService();
    await tester.pumpWidget(
      MaterialApp(
        home: AccountSettingsPage(
          section: 'preferences',
          accountService: service,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Order notifications'));
    await tester.pump();
    await tester.tap(find.text('Account notifications'));
    await tester.pump();
    service.requests['accountNotifications']!.complete();
    await tester.pump();
    service.requests['orderNotifications']!.complete();
    await tester.pumpAndSettle();
    final switches = tester
        .widgetList<SwitchListTile>(find.byType(SwitchListTile))
        .toList();
    expect(switches[0].value, isTrue);
    expect(switches[1].value, isTrue);
  });
}
