import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:india_trading_app/l10n/app_language.dart';
import 'package:india_trading_app/pages/language_page.dart';
import 'package:india_trading_app/services/client_account_service.dart';

class LanguageService extends ClientAccountService {
  int calls = 0;
  Completer<void> pending = Completer<void>();
  @override
  Future<void> updatePreferences(Map<String, dynamic> data) {
    calls++;
    return pending.future;
  }
}

void main() {
  testWidgets(
    'rapid language selection sends one request and failure permits retry',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await AppLanguage.instance.select('en');
      final service = LanguageService();
      await tester.pumpWidget(
        MaterialApp(home: LanguagePage(accountService: service)),
      );
      final tap = tester
          .widget<ListTile>(find.widgetWithText(ListTile, 'हिन्दी'))
          .onTap!;
      tap();
      tap();
      expect(service.calls, 1);
      service.pending.completeError(Exception('offline'));
      await tester.pumpAndSettle();
      expect(AppLanguage.instance.code, 'en');
      expect(find.text('Unable to save language'), findsOneWidget);
      service.pending = Completer<void>();
      await tester.tap(find.text('हिन्दी'));
      expect(service.calls, 2);
      service.pending.complete();
      await tester.pumpAndSettle();
      expect(AppLanguage.instance.code, 'hi');
      expect(find.byType(LinearProgressIndicator), findsNothing);
      await AppLanguage.instance.select('en');
    },
  );
}
