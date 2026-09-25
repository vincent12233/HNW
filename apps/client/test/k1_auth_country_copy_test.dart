import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:india_trading_app/pages/login_page.dart';
import 'package:india_trading_app/pages/register_page.dart';
import 'package:india_trading_app/theme/app_motion.dart';
import 'package:india_trading_app/theme/app_theme.dart';
import 'package:india_trading_app/widgets/international_phone_field.dart';
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

InternationalPhoneField phoneField(WidgetTester tester) {
  return tester.widget<InternationalPhoneField>(
    find.byType(InternationalPhoneField),
  );
}

void expectNoSmsEmailOtpCopy(WidgetTester tester) {
  expect(find.textContaining('SMS'), findsNothing);
  expect(find.textContaining('email verification'), findsNothing);
  expect(find.textContaining('email code'), findsNothing);
  expect(find.textContaining('Aadhaar OTP'), findsNothing);
  expect(find.textContaining('OTP'), findsNothing);
}

const _captureDir = '/tmp/hnw-k1-auth-copy';

Future<void> captureCurrent(WidgetTester tester, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('k1-capture')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory(_captureDir).createSync(recursive: true);
    File('$_captureDir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

Future<void> captureScreen(
  WidgetTester tester,
  String name,
  Size size,
  Widget home, {
  double textScale = 1,
  bool reduceMotion = true,
}) async {
  setView(tester, size);
  await tester.pumpWidget(
    RepaintBoundary(
      key: const ValueKey('k1-capture'),
      child: host(
        home,
        size: size,
        textScale: textScale,
        reduceMotion: reduceMotion,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  final error = tester.takeException();
  if (error != null && !error.toString().contains('RenderAnimatedSize')) {
    fail('$error');
  }
  await captureCurrent(tester, name);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('login defaults to +91 with an operable country selector', (
    tester,
  ) async {
    setView(tester, const Size(390, 844));
    await tester.pumpWidget(host(LoginPage(onSignedIn: (_) {})));
    expect(find.text('+91'), findsOneWidget);
    expect(phoneField(tester).country.countryCode, 'IN');
    expect(phoneField(tester).lockCountry, isFalse);
    expect(find.byTooltip('India flag, country code +91'), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
    await tester.tap(find.byTooltip('India flag, country code +91'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(TextField), findsNWidgets(3));
    expectNoSmsEmailOtpCopy(tester);
    expect(tester.takeException(), isNull);
    await disposeTree(tester);
  });

  testWidgets('register defaults to +91 and keeps compact invite copy', (
    tester,
  ) async {
    setView(tester, const Size(390, 844));
    await tester.pumpWidget(host(const RegisterPage()));
    await tester.pump(AppMotion.entranceRegister);
    expect(find.text('+91'), findsOneWidget);
    expect(phoneField(tester).country.countryCode, 'IN');
    expect(phoneField(tester).lockCountry, isFalse);
    expect(find.text('Invite Code is Mandatory'), findsOneWidget);
    expect(
      find.text('A valid invite code is required to create an account.'),
      findsOneWidget,
    );
    expect(find.textContaining('No SMS or email verification is sent.'), findsNothing);
    expect(find.textContaining('You need a valid invite code to create an account.'), findsNothing);
    expectNoSmsEmailOtpCopy(tester);
    expect(tester.takeException(), isNull);
    await disposeTree(tester);
  });

  testWidgets('switching country keeps filled auth fields', (tester) async {
    setView(tester, const Size(390, 2000));
    await tester.pumpWidget(
      host(const RegisterPage(), size: const Size(390, 2000)),
    );
    await tester.enterText(find.byType(TextField).at(0), '9876543210');
    await tester.enterText(find.byType(TextField).at(1), 'password1');
    await tester.enterText(find.byType(TextField).at(2), 'password1');
    await tester.enterText(find.byType(TextField).at(3), 'invite99');
    phoneField(tester).onCountryChanged(Country.parse('US'));
    await tester.pump();
    expect(find.text('+1'), findsOneWidget);
    expect(find.text('9876543210'), findsOneWidget);
    expect(find.text('password1'), findsNWidgets(2));
    expect(find.text('INVITE99'), findsOneWidget);
    expect(find.text('Invite Code is Mandatory'), findsOneWidget);
    await disposeTree(tester);
  });

  testWidgets('login country change does not clear the password', (
    tester,
  ) async {
    setView(tester, const Size(390, 844));
    await tester.pumpWidget(host(LoginPage(onSignedIn: (_) {})));
    await tester.enterText(find.byType(TextField).at(0), '9876543210');
    await tester.enterText(find.byType(TextField).at(1), 'password1');
    phoneField(tester).onCountryChanged(Country.parse('GB'));
    await tester.pump();
    expect(find.text('+44'), findsOneWidget);
    expect(find.text('9876543210'), findsOneWidget);
    expect(find.text('password1'), findsOneWidget);
    await disposeTree(tester);
  });

  testWidgets('register request still sends only phone password inviteCode', (
    tester,
  ) async {
    setView(tester, const Size(390, 2000));
    late Map<String, dynamic> body;
    var calls = 0;
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
        expect(calls, 1);
        await disposeTree(tester);
      },
      () {
        return MockClient((request) async {
          calls += 1;
          body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(request.url.path, '/auth/register');
          return http.Response(
            jsonEncode({'message': 'Invalid invite code'}),
            400,
          );
        });
      },
    );
    expect(body.keys.toSet(), {'phone', 'password', 'inviteCode'});
    expect(body['phone'], '+919876543210');
    expect(body['password'], 'password1');
    expect(body['inviteCode'], 'INVITE99');
    expect(body.containsKey('smsOtp'), isFalse);
    expect(body.containsKey('verificationCode'), isFalse);
    expect(body.containsKey('confirmPassword'), isFalse);
  });

  testWidgets('login request still sends phone and password only', (
    tester,
  ) async {
    setView(tester, const Size(390, 844));
    late Map<String, dynamic> body;
    var calls = 0;
    await http.runWithClient(
      () async {
        await tester.pumpWidget(host(LoginPage(onSignedIn: (_) {})));
        await tester.enterText(find.byType(TextField).at(0), '9876543210');
        await tester.enterText(find.byType(TextField).at(1), 'password1');
        await tester.tap(find.text('Login'));
        await tester.pump();
        expect(calls, 1);
        await disposeTree(tester);
      },
      () {
        return MockClient((request) async {
          calls += 1;
          body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(request.url.path, '/auth/login');
          return http.Response(jsonEncode({'message': 'Invalid credentials'}), 401);
        });
      },
    );
    expect(body.keys.toSet(), {'phone', 'password'});
    expect(body['phone'], '+919876543210');
    expect(body.containsKey('smsOtp'), isFalse);
    expect(body.containsKey('verificationCode'), isFalse);
  });

  testWidgets('TOTP verificationCode is unchanged after country restore', (
    tester,
  ) async {
    setView(tester, const Size(390, 844));
    late Map<String, dynamic> body;
    var calls = 0;
    await http.runWithClient(
      () async {
        await tester.pumpWidget(host(LoginPage(onSignedIn: (_) {})));
        await tester.enterText(find.byType(TextField).at(0), '9876543210');
        await tester.enterText(find.byType(TextField).at(1), 'password1');
        await tester.tap(find.text('Login'));
        await tester.pump();
        await tester.pump();
        await tester.pump(AppMotion.state);
        expect(find.text('Authenticator or recovery code'), findsOneWidget);
        final totp = tester.widget<TextField>(find.byType(TextField).at(2));
        expect(
          totp.decoration?.helperText,
          'Use the authenticator app or a support-issued recovery code.',
        );
        expect(totp.decoration?.helperText, isNot(contains('SMS')));
        expect(find.textContaining('No SMS code is sent.'), findsNothing);
        expectNoSmsEmailOtpCopy(tester);
        await tester.enterText(find.byType(TextField).at(2), '123456');
        await tester.tap(find.text('Login'));
        await tester.pump();
        await tester.pump();
        expect(calls, 2);
        await disposeTree(tester);
      },
      () {
        return MockClient((request) async {
          calls += 1;
          body = jsonDecode(request.body) as Map<String, dynamic>;
          if (calls == 1) {
            return http.Response(
              jsonEncode({
                'twoFactorRequired': true,
                'message': 'Two-factor required',
              }),
              401,
            );
          }
          return http.Response(jsonEncode({'message': 'Invalid code'}), 401);
        });
      },
    );
    expect(body.keys.toSet(), {'phone', 'password', 'verificationCode'});
    expect(body['verificationCode'], '123456');
    expect(body.containsKey('smsOtp'), isFalse);
  });

  testWidgets('auth screens fit listed phones and text scales', (tester) async {
    const sizes = <Size>[
      Size(320, 568),
      Size(390, 844),
      Size(414, 896),
      Size(768, 1024),
    ];
    for (final size in sizes) {
      for (final scale in <double>[1, 1.3, 1.5]) {
        setView(tester, size);
        await tester.pumpWidget(
          host(
            LoginPage(onSignedIn: (_) {}),
            size: size,
            textScale: scale,
            reduceMotion: true,
          ),
        );
        await tester.pump();
        expect(find.text('+91'), findsOneWidget, reason: 'login $size x$scale');
        final loginError = tester.takeException();
        expect(
          loginError,
          isNull,
          reason: 'login $size x$scale $loginError',
        );

        await tester.pumpWidget(
          host(
            const RegisterPage(),
            size: size,
            textScale: scale,
            reduceMotion: true,
          ),
        );
        await tester.pump();
        expect(find.text('+91'), findsOneWidget, reason: 'register $size x$scale');
        expect(find.text('Invite Code is Mandatory'), findsOneWidget);
        expect(
          find.text('A valid invite code is required to create an account.'),
          findsOneWidget,
        );
        expectNoSmsEmailOtpCopy(tester);
        expect(tester.takeException(), isNull, reason: 'register $size x$scale');
      }
    }
    await disposeTree(tester);
  });

  testWidgets('write K.1 auth screenshots for visual review', (tester) async {
    const sizes = <Size>[
      Size(320, 568),
      Size(390, 844),
      Size(414, 896),
      Size(768, 1024),
    ];
    for (final size in sizes) {
      final tag = '${size.width.toInt()}x${size.height.toInt()}';
      await captureScreen(
        tester,
        'login-default-$tag',
        size,
        LoginPage(onSignedIn: (_) {}),
      );
      await captureScreen(
        tester,
        'register-invite-$tag',
        size,
        const RegisterPage(),
      );
    }
    await captureScreen(
      tester,
      'login-text-1.3-390x844',
      const Size(390, 844),
      LoginPage(onSignedIn: (_) {}),
      textScale: 1.3,
    );
    await captureScreen(
      tester,
      'register-text-1.5-390x844',
      const Size(390, 844),
      const RegisterPage(),
      textScale: 1.5,
    );
    await captureScreen(
      tester,
      'login-reduced-motion-320x568',
      const Size(320, 568),
      LoginPage(onSignedIn: (_) {}),
      reduceMotion: true,
    );

    setView(tester, const Size(390, 844));
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('k1-capture'),
        child: host(LoginPage(onSignedIn: (_) {}), reduceMotion: true),
      ),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextField).at(0), '9876543210');
    await tester.enterText(find.byType(TextField).at(1), 'password1');
    await tester.tap(find.byTooltip('India flag, country code +91'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await captureCurrent(tester, 'login-country-picker-390x844');
    phoneField(tester).onCountryChanged(Country.parse('US'));
    await tester.pump();
    expect(find.text('9876543210'), findsOneWidget);
    expect(find.text('password1'), findsOneWidget);
    await captureCurrent(tester, 'login-country-switched-keeps-phone-390x844');
    await disposeTree(tester);
  });
}
