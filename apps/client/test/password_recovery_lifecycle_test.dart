import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:india_trading_app/pages/forgot_password_page.dart';

void main() {
  testWidgets('leaving during recovery load does not restart polling', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({'recovery_token': 'test'});
    final pending = Completer<http.Response>();
    var calls = 0;
    await http.runWithClient(
      () async {
        await tester.pumpWidget(const MaterialApp(home: ForgotPasswordPage()));
        await tester.pump();
        expect(calls, 1);
        await tester.pumpWidget(const SizedBox.shrink());
        pending.complete(http.Response('{"messages":[],"status":"OPEN"}', 200));
        await tester.pump();
        await tester.pump(const Duration(seconds: 10));
        expect(calls, 1);
        expect(tester.takeException(), isNull);
      },
      () => MockClient((_) {
        calls++;
        return pending.future;
      }),
    );
  });
  testWidgets('expired non-JSON response clears recovery token', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({'recovery_token': 'expired'});
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: ForgotPasswordPage()));
      await tester.pumpAndSettle();
      expect(
        await const FlutterSecureStorage().read(key: 'recovery_token'),
        isNull,
      );
      expect(find.text('Connect to Support'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => MockClient((_) async => http.Response('Unauthorized', 401)));
  });
}
