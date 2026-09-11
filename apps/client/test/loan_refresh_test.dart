import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:india_trading_app/pages/loan_page.dart';
import 'package:india_trading_app/services/client_account_service.dart';

class RefreshLoanService extends ClientAccountService {
  int reads = 0;
  final pending = Completer<List<Map<String, dynamic>>>();
  @override
  Future<List<Map<String, dynamic>>> loans() async {
    if (++reads == 1) {
      return [
        {'orderNo': 'LN1', 'status': 'REJECTED'},
      ];
    }
    return pending.future;
  }
}

void main() {
  testWidgets(
    'refresh retains records and disables application until settled',
    (tester) async {
      final service = RefreshLoanService();
      await tester.pumpWidget(MaterialApp(home: LoanPage(service: service)));
      await tester.pumpAndSettle();
      final refresh = tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh();
      await tester.pump();
      expect(find.text('LN1'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      service.pending.complete([
        {'orderNo': 'LN2', 'status': 'PENDING'},
      ]);
      await refresh;
      await tester.pumpAndSettle();
      expect(find.text('LN2'), findsOneWidget);
      expect(find.text('LN1'), findsNothing);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
