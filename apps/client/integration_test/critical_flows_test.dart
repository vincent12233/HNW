import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:india_trading_app/pages/login_page.dart';
import 'package:india_trading_app/pages/register_page.dart';
import 'package:india_trading_app/pages/withdrawal_page.dart';
import 'package:india_trading_app/models/withdrawal_request.dart';
import 'package:india_trading_app/services/auth_service.dart';
import 'package:india_trading_app/services/client_account_service.dart';
import 'package:india_trading_app/theme/app_theme.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Widget host(Widget child) {
    return MaterialApp(theme: AppTheme.light(), home: child);
  }

  testWidgets('login blocks invalid credentials before network access', (
    tester,
  ) async {
    await tester.pumpWidget(host(LoginPage(onSignedIn: (_) {})));
    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid Indian mobile number'), findsOneWidget);
    expect(find.text('Password must be at least 8 characters'), findsOneWidget);
  });

  testWidgets(
    'registration validates invite, password and consent before submit',
    (tester) async {
      await tester.pumpWidget(host(const RegisterPage()));
      await tester.tap(find.text('Sign Up'));
      await tester.pumpAndSettle();
      expect(find.text('Invite code is required'), findsOneWidget);
      expect(
        find.text('Password must be at least 8 characters'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'withdrawal keeps the server-confirmed state and input validation',
    (tester) async {
      await tester.pumpWidget(
        host(
          WithdrawalPage(
            availableBalance: 1000,
            frozenBalance: 0,
            authService: _IntegrationAuth(),
            accountService: _IntegrationAccount(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), '50');
      await tester.enterText(find.byType(TextField).at(1), '123');
      await tester.tap(find.text('Submit Request'));
      await tester.pumpAndSettle();
      expect(find.text('Minimum withdrawal amount is ₹100'), findsOneWidget);
      expect(find.text('50'), findsOneWidget);
    },
  );
}

class _IntegrationAuth extends AuthService {
  @override
  Future<List<WithdrawalRequest>> fetchWithdrawals() async => const [];

  @override
  Future<WithdrawalRequest> submitWithdrawal({
    required String withdrawalPin,
    required double amount,
    required String bankName,
    required String accountNumber,
    required String ifscCode,
    String? note,
    String? idempotencyKey,
  }) async {
    throw StateError('submission should be blocked by validation');
  }
}

class _IntegrationAccount extends ClientAccountService {
  @override
  Future<bool> hasWithdrawalPin() async => true;

  @override
  Future<List<Map<String, dynamic>>> banks() async => [
    {
      'id': 'bank-1',
      'bankName': 'HDFC',
      'accountNumber': '1234567890',
      'ifscCode': 'HDFC0001',
      'accountHolder': 'Integration User',
      'isPrimary': true,
      'status': 'Added',
    },
  ];
}
