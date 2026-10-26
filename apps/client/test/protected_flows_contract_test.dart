import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:india_trading_app/pages/deposit_page.dart';
import 'package:india_trading_app/pages/forgot_password_page.dart';
import 'package:india_trading_app/pages/login_page.dart';
import 'package:india_trading_app/pages/register_page.dart';
import 'package:india_trading_app/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  Widget app(Widget home) => MaterialApp(theme: AppTheme.light(), home: home);

  testWidgets(
    'registration keeps phone password and invite without OTP or email',
    (tester) async {
      await tester.pumpWidget(app(const RegisterPage()));

      expect(find.text('Invite Code'), findsWidgets);
      expect(find.text('Password'), findsOneWidget);
      expect(find.textContaining('OTP'), findsNothing);
      expect(find.textContaining('Email'), findsNothing);
    },
  );

  testWidgets('login starts with phone and password only', (tester) async {
    await tester.pumpWidget(app(LoginPage(onSignedIn: (_) {})));

    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Authenticator or recovery code'), findsNothing);
    expect(find.textContaining('SMS OTP'), findsNothing);
  });

  testWidgets('password recovery remains a support-issued code journey', (
    tester,
  ) async {
    await tester.pumpWidget(app(const ForgotPasswordPage()));
    await tester.pumpAndSettle();

    expect(find.textContaining('support'), findsWidgets);
    expect(find.textContaining('recovery code'), findsWidgets);
    expect(find.textContaining('email reset'), findsNothing);
  });

  testWidgets('deposit remains support-assisted without a payment form', (
    tester,
  ) async {
    await tester.pumpWidget(app(const DepositPage()));
    await tester.pump();

    expect(find.textContaining('Contact customer support'), findsWidgets);
    expect(find.textContaining('finance'), findsWidgets);
    expect(find.byType(TextFormField), findsNothing);
  });
}
