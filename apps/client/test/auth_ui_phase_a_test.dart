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
import 'package:india_trading_app/pages/splash_page.dart';
import 'package:india_trading_app/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('login keeps request fields and blocks repeat submit', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final pending = Completer<http.Response>();
    var calls = 0;
    late Map<String, dynamic> body;

    await http.runWithClient(() async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: LoginPage(onSignedIn: (_) {}),
        ),
      );
      expect(find.text('HNW'), findsOneWidget);
      expect(find.text('+91'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.byTooltip('Show password'), findsOneWidget);
      expect(find.textContaining('OTP'), findsNothing);
      expect(find.textContaining('SMS OTP'), findsNothing);

      await tester.enterText(find.byType(TextField).at(0), '9876543210');
      await tester.enterText(find.byType(TextField).at(1), 'password1');
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      expect(calls, 1);
      await tester.pumpWidget(const SizedBox.shrink());
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
    }, () {
      return MockClient((request) async {
        calls++;
        body = jsonDecode(request.body) as Map<String, dynamic>;
        return pending.future;
      });
    });

    expect(body.keys.toSet(), {'phone', 'password'});
    expect(body.containsKey('confirmPassword'), isFalse);
    expect(body.containsKey('smsOtp'), isFalse);
    expect(body.containsKey('verificationCode'), isFalse);
  });

  testWidgets('login shows field errors and keeps the phone number', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: LoginPage(onSignedIn: (_) {}),
      ),
    );
    await tester.enterText(find.byType(TextField).at(0), '9876543210');
    await tester.tap(find.text('Login'));
    await tester.pump();
    expect(find.text('Password must be at least 8 characters'), findsOneWidget);
    expect(find.text('9876543210'), findsOneWidget);
  });

  testWidgets('login maps server and network errors into the form', (
    tester,
  ) async {
    await http.runWithClient(() async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: LoginPage(onSignedIn: (_) {}),
        ),
      );
      await tester.enterText(find.byType(TextField).at(0), '9876543210');
      await tester.enterText(find.byType(TextField).at(1), 'password1');
      await tester.tap(find.text('Login'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Account is suspended'), findsOneWidget);
      expect(find.text('9876543210'), findsOneWidget);
    }, () {
      return MockClient(
        (_) async => http.Response(
          jsonEncode({'message': 'Account is suspended'}),
          403,
        ),
      );
    });
  });

  testWidgets('login shows session expiry notice without changing fields', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: LoginPage(
          notice: 'Your session has expired. Please sign in again.',
          onSignedIn: (_) {},
        ),
      ),
    );
    expect(
      find.text('Your session has expired. Please sign in again.'),
      findsOneWidget,
    );
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Authenticator or recovery code'), findsNothing);
  });

  testWidgets('register posts phone password inviteCode only and opens KYC', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    late Map<String, dynamic> body;
    await http.runWithClient(() async {
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.light(), home: const RegisterPage()),
      );
      await tester.enterText(find.byType(TextField).at(0), '9876543210');
      await tester.enterText(find.byType(TextField).at(1), 'password1');
      await tester.enterText(find.byType(TextField).at(2), 'password1');
      await tester.enterText(find.byType(TextField).at(3), 'invite99');
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.tap(find.text('Sign Up'));
      await tester.pump();
      await tester.pump();
      expect(find.byType(KycUploadPage), findsOneWidget);
      expect(find.text('ACTIVE'), findsNothing);
    }, () {
      return MockClient((request) async {
        body = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'message': 'Registration successful',
            'kycToken': 'kyc-token',
            'user': {'id': 'u1', 'status': 'SUSPENDED'},
          }),
          201,
        );
      });
    });
    expect(body.keys.toSet(), {'phone', 'password', 'inviteCode'});
    expect(body.containsKey('confirmPassword'), isFalse);
    expect(body['inviteCode'], 'INVITE99');
  });

  testWidgets('register requires invite code and keeps field errors nearby', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light(), home: const RegisterPage()),
    );
    await tester.enterText(find.byType(TextField).at(0), '9876543210');
    await tester.enterText(find.byType(TextField).at(1), 'password1');
    await tester.enterText(find.byType(TextField).at(2), 'password1');
    await tester.ensureVisible(find.byType(Checkbox));
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.ensureVisible(find.text('Sign Up'));
    await tester.tap(find.text('Sign Up'));
    await tester.pump();
    expect(find.text('Invite code is required'), findsOneWidget);
    expect(find.textContaining('OTP'), findsNothing);
  });

  testWidgets('recovery page is a support path and does not claim a sent code', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: ForgotPasswordPage()),
    );
    await tester.pump();
    expect(find.text('Connect to Support'), findsOneWidget);
    expect(find.textContaining('customer support'), findsWidgets);
    expect(find.textContaining('verification code has been sent'), findsNothing);
    expect(find.textContaining('OTP'), findsNothing);
  });

  testWidgets('login posts verificationCode only after authenticator is required', (
    tester,
  ) async {
    var calls = 0;
    late Map<String, dynamic> secondBody;
    final pending = Completer<http.Response>();
    await http.runWithClient(() async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: LoginPage(onSignedIn: (_) {}),
        ),
      );
      await tester.enterText(find.byType(TextField).at(0), '9876543210');
      await tester.enterText(find.byType(TextField).at(1), 'password1');
      await tester.tap(find.text('Login'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Authenticator or recovery code'), findsOneWidget);
      expect(find.textContaining('SMS OTP'), findsNothing);
      expect(find.textContaining('recovery code'), findsWidgets);
      await tester.enterText(find.byType(TextField).at(2), '123456');
      await tester.tap(find.text('Login'));
      await tester.pump();
      expect(calls, 2);
      await tester.pumpWidget(const SizedBox.shrink());
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
    }, () {
      return MockClient((request) async {
        calls++;
        if (calls == 1) {
          return http.Response(
            jsonEncode({'twoFactorRequired': true, 'message': 'Two-factor required'}),
            401,
          );
        }
        secondBody = jsonDecode(request.body) as Map<String, dynamic>;
        return pending.future;
      });
    });
    expect(calls, 2);
    expect(secondBody.keys.toSet(), {'phone', 'password', 'verificationCode'});
    expect(secondBody['verificationCode'], '123456');
    expect(secondBody.containsKey('smsOtp'), isFalse);
  });

  testWidgets('login maps a network failure into the form and keeps the phone', (
    tester,
  ) async {
    await http.runWithClient(() async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: LoginPage(onSignedIn: (_) {}),
        ),
      );
      await tester.enterText(find.byType(TextField).at(0), '9876543210');
      await tester.enterText(find.byType(TextField).at(1), 'password1');
      await tester.tap(find.text('Login'));
      await tester.pump();
      await tester.pump();
      expect(
        find.text('Unable to connect. Please check your network and try again.'),
        findsOneWidget,
      );
      expect(find.text('9876543210'), findsOneWidget);
    }, () {
      return MockClient((request) async {
        throw http.ClientException('Failed to fetch', request.url);
      });
    });
  });

  testWidgets('register blocks a second submit and never sends confirmPassword', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final pending = Completer<http.Response>();
    var calls = 0;
    late Map<String, dynamic> body;
    await http.runWithClient(() async {
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.light(), home: const RegisterPage()),
      );
      await tester.enterText(find.byType(TextField).at(0), '9876543210');
      await tester.enterText(find.byType(TextField).at(1), 'password1');
      await tester.enterText(find.byType(TextField).at(2), 'password1');
      await tester.enterText(find.byType(TextField).at(3), 'invite99');
      await tester.ensureVisible(find.byType(Checkbox));
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.ensureVisible(find.text('Sign Up'));
      await tester.tap(find.text('Sign Up'));
      await tester.pump();
      await tester.tap(find.byType(FilledButton), warnIfMissed: false);
      await tester.pump();
      expect(calls, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      pending.complete(
        http.Response(
          jsonEncode({
            'message': 'Registration successful',
            'kycToken': 'kyc-token',
            'user': {'id': 'u1', 'status': 'SUSPENDED'},
          }),
          201,
        ),
      );
      await tester.pump();
    }, () {
      return MockClient((request) async {
        calls++;
        body = jsonDecode(request.body) as Map<String, dynamic>;
        return pending.future;
      });
    });
    expect(body.keys.toSet(), {'phone', 'password', 'inviteCode'});
    expect(body.containsKey('confirmPassword'), isFalse);
  });

  testWidgets('register maps duplicate phone and invite errors near fields', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await http.runWithClient(() async {
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.light(), home: const RegisterPage()),
      );
      await tester.enterText(find.byType(TextField).at(0), '9876543210');
      await tester.enterText(find.byType(TextField).at(1), 'password1');
      await tester.enterText(find.byType(TextField).at(2), 'password1');
      await tester.enterText(find.byType(TextField).at(3), 'invite99');
      await tester.ensureVisible(find.byType(Checkbox));
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.ensureVisible(find.text('Sign Up'));
      await tester.tap(find.text('Sign Up'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Phone number already registered'), findsOneWidget);
      expect(find.textContaining('OTP'), findsNothing);
    }, () {
      return MockClient(
        (_) async => http.Response(
          jsonEncode({'message': 'Phone number already registered'}),
          409,
        ),
      );
    });
  });

  testWidgets('splash states are display-only session messages', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SplashPage(
          status: 'Checking saved session',
          detail: 'Starting the app and verifying any saved token.',
        ),
      ),
    );
    expect(find.text('HNW'), findsOneWidget);
    expect(find.text('Checking saved session'), findsOneWidget);
    expect(find.text('Starting the app and verifying any saved token.'), findsOneWidget);
    expect(find.text('SUSPENDED'), findsNothing);
    expect(find.text('ACTIVE'), findsNothing);
    expect(find.text('DISABLED'), findsNothing);
  });

  testWidgets('password toggle has an accessible name', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: LoginPage(onSignedIn: (_) {}),
      ),
    );
    expect(find.byTooltip('Show password'), findsOneWidget);
    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();
    expect(find.byTooltip('Hide password'), findsOneWidget);
  });

  testWidgets('auth screens keep fields usable at text scale 1.3', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(390, 844),
          textScaler: TextScaler.linear(1.3),
        ),
        child: MaterialApp(
          theme: AppTheme.light(),
          home: LoginPage(onSignedIn: (_) {}),
        ),
      ),
    );
    expect(find.text('Login'), findsOneWidget);
    expect(find.text('+91'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('login register and recovery fit listed viewports', (
    tester,
  ) async {
    const sizes = <Size>[
      Size(320, 568),
      Size(360, 640),
      Size(375, 667),
      Size(390, 844),
      Size(393, 852),
      Size(412, 915),
      Size(430, 932),
      Size(480, 960),
      Size(768, 1024),
      Size(1024, 768),
      Size(1440, 900),
    ];
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;

    for (final size in sizes) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: LoginPage(onSignedIn: (_) {}),
        ),
      );
      await tester.pump();
      expect(find.text('HNW'), findsWidgets, reason: 'login $size');
      expect(tester.takeException(), isNull, reason: 'login overflow $size');

      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.light(), home: const RegisterPage()),
      );
      await tester.pump();
      expect(find.text('Create Account'), findsOneWidget, reason: 'register $size');
      expect(tester.takeException(), isNull, reason: 'register overflow $size');

      await tester.pumpWidget(
        const MaterialApp(home: ForgotPasswordPage()),
      );
      await tester.pump();
      expect(find.text('Connect to Support'), findsOneWidget, reason: 'recovery $size');
      expect(tester.takeException(), isNull, reason: 'recovery overflow $size');
    }
  });
}
