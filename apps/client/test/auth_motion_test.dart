import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:india_trading_app/pages/forgot_password_page.dart';
import 'package:india_trading_app/pages/kyc_upload_page.dart';
import 'package:india_trading_app/pages/login_page.dart';
import 'package:india_trading_app/pages/register_page.dart';
import 'package:india_trading_app/theme/app_motion.dart';
import 'package:india_trading_app/theme/app_theme.dart';
import 'package:india_trading_app/theme/auth_layout.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget host(
  Widget child, {
  Size size = const Size(390, 844),
  double textScale = 1,
  bool reduceMotion = false,
}) {
  return MaterialApp(
    theme: AppTheme.light(),
    builder: (context, content) {
      final media = MediaQuery.of(context);
      return MediaQuery(
        data: media.copyWith(
          size: size,
          textScaler: TextScaler.linear(textScale),
          disableAnimations: reduceMotion,
          accessibleNavigation: reduceMotion,
        ),
        child: content!,
      );
    },
    home: child,
  );
}

void setView(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> disposeTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('login entrance settles without blocking input', (tester) async {
    setView(tester, const Size(390, 844));
    await tester.pumpWidget(host(LoginPage(onSignedIn: (_) {})));
    expect(find.text('HNW'), findsOneWidget);
    expect(find.text('Welcome Back!'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(0), '9876543210');
    await tester.pump(AppMotion.entrance);
    expect(find.text('Login'), findsOneWidget);
    expect(find.text('9876543210'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await disposeTree(tester);
  });

  testWidgets('register entrance keeps every required field', (tester) async {
    setView(tester, const Size(390, 844));
    await tester.pumpWidget(host(const RegisterPage()));
    await tester.pump(AppMotion.entranceRegister);
    expect(find.text('Create Account'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Confirm Password'), findsOneWidget);
    expect(find.text('Invite Code'), findsOneWidget);
    expect(find.text('Sign Up'), findsOneWidget);
    expect(find.textContaining('OTP'), findsNothing);
    expect(tester.takeException(), isNull);
    await disposeTree(tester);
  });

  testWidgets('login to register uses the existing navigator', (tester) async {
    setView(tester, const Size(390, 844));
    await tester.pumpWidget(host(LoginPage(onSignedIn: (_) {})));
    await tester.tap(find.text('Create Account'));
    await tester.pump();
    await tester.pump(AppMotion.page);
    expect(find.text('Create Account'), findsWidgets);
    expect(find.text('Invite Code'), findsOneWidget);
    await tester.pageBack();
    await tester.pump();
    await tester.pump(AppMotion.page);
    expect(find.text('Welcome Back!'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
    await disposeTree(tester);
  });

  testWidgets('password toggle keeps the tooltip and field value', (
    tester,
  ) async {
    setView(tester, const Size(390, 844));
    await tester.pumpWidget(host(LoginPage(onSignedIn: (_) {})));
    await tester.enterText(find.byType(TextField).at(1), 'password1');
    expect(find.byTooltip('Show password'), findsOneWidget);
    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();
    await tester.pump(AppMotion.micro);
    expect(find.byTooltip('Hide password'), findsOneWidget);
    expect(find.text('password1'), findsOneWidget);
    await disposeTree(tester);
  });

  testWidgets('loading keeps the 48px button and sends one request', (
    tester,
  ) async {
    setView(tester, const Size(390, 844));
    final pending = Completer<http.Response>();
    var calls = 0;
    late Map<String, dynamic> body;
    await http.runWithClient(
      () async {
        await tester.pumpWidget(host(LoginPage(onSignedIn: (_) {})));
        await tester.enterText(find.byType(TextField).at(0), '9876543210');
        await tester.enterText(find.byType(TextField).at(1), 'password1');
        await tester.tap(find.text('Login'));
        await tester.pump();
        final button = tester.getSize(find.byType(FilledButton));
        expect(button.height, AuthLayout.buttonHeight);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.byKey(const ValueKey('auth-success')), findsNothing);
        await tester.tap(find.byType(FilledButton), warnIfMissed: false);
        await tester.pump();
        expect(calls, 1);
        await disposeTree(tester);
        pending.complete(http.Response('{}', 500));
      },
      () {
        return MockClient((request) async {
          calls += 1;
          body = jsonDecode(request.body) as Map<String, dynamic>;
          return pending.future;
        });
      },
    );
    expect(body.keys.toSet(), {'phone', 'password'});
    expect(body.containsKey('verificationCode'), isFalse);
    expect(body.containsKey('smsOtp'), isFalse);
  });

  testWidgets('success icon appears only after the server accepts login', (
    tester,
  ) async {
    setView(tester, const Size(390, 844));
    final pending = Completer<http.Response>();
    var signedIn = 0;
    await http.runWithClient(
      () async {
        await tester.pumpWidget(
          host(LoginPage(onSignedIn: (_) => signedIn += 1)),
        );
        await tester.enterText(find.byType(TextField).at(0), '9876543210');
        await tester.enterText(find.byType(TextField).at(1), 'password1');
        await tester.tap(find.text('Login'));
        await tester.pump();
        expect(find.byKey(const ValueKey('auth-success')), findsNothing);
        expect(signedIn, 0);
        pending.complete(
          http.Response(
            jsonEncode({
              'accessToken': 'a',
              'refreshToken': 'r',
              'user': {'id': 'u1', 'role': 'CLIENT', 'status': 'ACTIVE'},
              'account': {'id': 'a1'},
            }),
            200,
          ),
        );
        await tester.pump();
        expect(find.byKey(const ValueKey('auth-success')), findsOneWidget);
        expect(signedIn, 0);
        await disposeTree(tester);
        await tester.pump(AppMotion.success);
      },
      () {
        return MockClient((_) => pending.future);
      },
    );
  });

  testWidgets('server failure never shows a success icon', (tester) async {
    setView(tester, const Size(390, 844));
    await http.runWithClient(
      () async {
        await tester.pumpWidget(host(LoginPage(onSignedIn: (_) {})));
        await tester.enterText(find.byType(TextField).at(0), '9876543210');
        await tester.enterText(find.byType(TextField).at(1), 'password1');
        await tester.tap(find.text('Login'));
        await tester.pump();
        await tester.pump();
        expect(find.text('Account is suspended'), findsOneWidget);
        expect(find.byKey(const ValueKey('auth-success')), findsNothing);
        expect(find.textContaining('SMS'), findsNothing);
        expect(find.text('9876543210'), findsOneWidget);
        await disposeTree(tester);
      },
      () {
        return MockClient(
          (_) async => http.Response(
            jsonEncode({'message': 'Account is suspended'}),
            403,
          ),
        );
      },
    );
  });

  testWidgets('register shows success then opens KYC after the server accepts', (
    tester,
  ) async {
    setView(tester, const Size(390, 2000));
    await http.runWithClient(
      () async {
        await tester.pumpWidget(
          host(const RegisterPage(), size: const Size(390, 2000)),
        );
        await tester.enterText(find.byType(TextField).at(0), '9876543210');
        await tester.enterText(find.byType(TextField).at(1), 'password1');
        await tester.enterText(find.byType(TextField).at(2), 'password1');
        await tester.enterText(find.byType(TextField).at(3), 'invite99');
        await tester.ensureVisible(find.byType(Checkbox));
        await tester.tap(find.byType(Checkbox));
        await tester.pump();
        await tester.ensureVisible(find.widgetWithText(FilledButton, 'Sign Up'));
        await tester.tap(find.widgetWithText(FilledButton, 'Sign Up'));
        await tester.pump();
        await tester.pump();
        expect(find.byKey(const ValueKey('auth-success')), findsOneWidget);
        expect(find.byType(KycUploadPage), findsNothing);
        await tester.pump(AppMotion.success);
        await tester.pump();
        expect(find.byType(KycUploadPage), findsOneWidget);
        await disposeTree(tester);
      },
      () {
        return MockClient(
          (_) async => http.Response(
            jsonEncode({
              'message': 'Registration successful',
              'kycToken': 'kyc-token',
              'user': {'id': 'u1', 'status': 'SUSPENDED'},
            }),
            201,
          ),
        );
      },
    );
  });

  testWidgets('TOTP field appears only after the current 2FA response', (
    tester,
  ) async {
    setView(tester, const Size(390, 844));
    await http.runWithClient(
      () async {
        await tester.pumpWidget(host(LoginPage(onSignedIn: (_) {})));
        expect(find.text('Authenticator or recovery code'), findsNothing);
        await tester.enterText(find.byType(TextField).at(0), '9876543210');
        await tester.enterText(find.byType(TextField).at(1), 'password1');
        await tester.tap(find.text('Login'));
        await tester.pump();
        await tester.pump();
        await tester.pump(AppMotion.state);
        expect(find.text('Authenticator or recovery code'), findsOneWidget);
        expect(find.textContaining('SMS OTP'), findsNothing);
        expect(
          find.textContaining('verification code has been sent'),
          findsNothing,
        );
        await disposeTree(tester);
      },
      () {
        return MockClient(
          (_) async => http.Response(
            jsonEncode({
              'twoFactorRequired': true,
              'message': 'Two-factor required',
            }),
            401,
          ),
        );
      },
    );
  });

  testWidgets('reduced motion still shows a usable login form', (tester) async {
    setView(tester, const Size(320, 568));
    await tester.pumpWidget(
      host(
        LoginPage(onSignedIn: (_) {}),
        size: const Size(320, 568),
        textScale: 1.3,
        reduceMotion: true,
      ),
    );
    await tester.pump();
    expect(find.text('HNW'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
    expect(find.text('+91'), findsOneWidget);
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    await tester.pump();
    expect(find.text('Login'), findsOneWidget);
    expect(tester.takeException(), isNull);
    tester.view.viewInsets = FakeViewPadding.zero;
    await disposeTree(tester);
  });

  testWidgets('session expiry notice is visible without waiting for entrance', (
    tester,
  ) async {
    setView(tester, const Size(390, 844));
    await tester.pumpWidget(
      host(
        LoginPage(
          notice: 'Your session has expired. Please sign in again.',
          onSignedIn: (_) {},
        ),
      ),
    );
    expect(
      find.text('Your session has expired. Please sign in again.'),
      findsOneWidget,
    );
    await disposeTree(tester);
  });

  testWidgets('recovery copy stays a support path', (tester) async {
    setView(tester, const Size(390, 844));
    await tester.pumpWidget(host(const ForgotPasswordPage()));
    await tester.pump();
    await tester.pump(AppMotion.entrance);
    expect(find.text('Connect to Support'), findsOneWidget);
    expect(find.textContaining('customer support'), findsWidgets);
    expect(
      find.textContaining('verification code has been sent'),
      findsNothing,
    );
    expect(find.textContaining('OTP'), findsNothing);
    await disposeTree(tester);
  });

  testWidgets('controllers dispose without ticker errors', (tester) async {
    setView(tester, const Size(390, 844));
    await tester.pumpWidget(host(LoginPage(onSignedIn: (_) {})));
    await tester.pump(const Duration(milliseconds: 80));
    await disposeTree(tester);
    expect(tester.takeException(), isNull);
  });
}
