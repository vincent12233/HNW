import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:india_trading_app/pages/loan_page.dart';
import 'package:india_trading_app/services/auth_service.dart';
import 'package:india_trading_app/services/client_account_service.dart';
import 'package:india_trading_app/theme/app_theme.dart';

class ErrorThenOkLoan extends ClientAccountService {
  int reads = 0;
  final gate = Completer<List<Map<String, dynamic>>>();
  @override
  Future<List<Map<String, dynamic>>> loans() {
    reads += 1;
    if (reads == 1) {
      return Future.error(const AuthException('offline'));
    }
    return gate.future;
  }
}

class DuplicateLoan extends ClientAccountService {
  int applies = 0;
  final gate = Completer<void>();
  @override
  Future<List<Map<String, dynamic>>> loans() async => [];
  @override
  Future<void> applyForLoan() {
    applies += 1;
    return gate.future;
  }
}

void main() {
  testWidgets('loan error is not empty', (tester) async {
    final service = ErrorThenOkLoan();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: LoanPage(service: service),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Unable to load loan applications'), findsWidgets);
    expect(find.text('No loan applications'), findsNothing);
    expect(find.text('Retry'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(service.reads, 2);
    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(service.reads, 2);
    service.gate.complete([
      {
        'orderNo': 'LN9',
        'status': 'PENDING',
        'createdAt': '2026-09-21T04:00:00.000Z',
      },
    ]);
    await tester.pumpAndSettle();
    expect(find.text('LN9'), findsOneWidget);
    expect(find.text('Pending Review'), findsWidgets);
  });

  testWidgets('loan submit stays disabled while in flight', (tester) async {
    final service = DuplicateLoan();
    tester.view.physicalSize = const Size(414, 896);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: LoanPage(service: service),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply for a Loan'));
    await tester.pump();
    await tester.tap(find.text('Apply for a Loan'));
    await tester.pump();
    expect(service.applies, 1);
    expect(find.text('LN pending'), findsNothing);
    service.gate.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('loan empty and reduced motion fit 414/768', (tester) async {
    for (final size in [const Size(414, 896), const Size(768, 1024)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              size: size,
              textScaler: const TextScaler.linear(1.3),
              disableAnimations: true,
            ),
            child: child!,
          ),
          home: LoanPage(service: DuplicateLoan()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('No loan applications'), findsOneWidget);
      expect(find.text('Apply for a Loan'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });
}
