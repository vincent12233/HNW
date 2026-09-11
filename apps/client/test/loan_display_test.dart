import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:india_trading_app/pages/loan_page.dart';
import 'package:india_trading_app/services/client_account_service.dart';

class DisplayLoanService extends ClientAccountService {
  @override
  Future<List<Map<String, dynamic>>> loans() async => [
    {
      'orderNo': 'LN20260911ABCDEFGHIJK',
      'status': 'DISBURSED',
      'approvedAmount': '12345678.99',
    },
    {'orderNo': 'LN2', 'status': 'UNRECOGNIZED', 'approvedAmount': 'NaN'},
  ];
}

void main() {
  for (final width in [320.0, 375.0, 430.0]) {
    testWidgets('loan records fit enlarged text at $width', (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
          home: LoanPage(service: DisplayLoanService()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Status unavailable'), findsOneWidget);
      expect(find.text('--'), findsOneWidget);
      expect(find.text('Pending Review'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
