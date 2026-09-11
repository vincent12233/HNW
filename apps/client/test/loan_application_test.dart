import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:india_trading_app/pages/loan_page.dart';
import 'package:india_trading_app/services/client_account_service.dart';

class LoanService extends ClientAccountService {
  int calls = 0;
  @override
  Future<List<Map<String, dynamic>>> loans() async => calls == 0
      ? []
      : [
          {'orderNo': 'LN1', 'status': 'PENDING'},
        ];
  @override
  Future<void> applyForLoan() async {
    calls++;
  }
}

void main() {
  testWidgets(
    'client applies without amount and cannot repeat pending request',
    (tester) async {
      final service = LoanService();
      await tester.pumpWidget(MaterialApp(home: LoanPage(service: service)));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      await tester.tap(find.text('Apply for a Loan'));
      await tester.pumpAndSettle();
      expect(service.calls, 1);
      expect(find.text('LN1'), findsOneWidget);
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
    },
  );
}
