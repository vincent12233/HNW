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
import 'package:india_trading_app/pages/forgot_password_page.dart';
import 'package:india_trading_app/pages/login_page.dart';
import 'package:india_trading_app/pages/register_page.dart';
import 'package:india_trading_app/theme/app_theme.dart';
import 'package:india_trading_app/widgets/international_phone_field.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Screenshots are optional; ordinary test runs must not write outside the repo.
// Enable with --dart-define=AUTH_CAPTURE_DIR=<output-directory>.
const _captureDir = String.fromEnvironment('AUTH_CAPTURE_DIR');

const _sizes = <Size>[
  Size(320, 568),
  Size(390, 844),
  Size(414, 896),
  Size(768, 1024),
];

const _scales = <double>[1, 1.3, 1.5];

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

Future<void> pumpUntilPhoneField(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump();
    if (find.byType(InternationalPhoneField).evaluate().isNotEmpty) {
      return;
    }
  }
  fail('phone field never appeared');
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

void expectNoOverflow(WidgetTester tester, String reason) {
  expect(tester.takeException(), isNull, reason: reason);
}

Future<void> captureCurrent(WidgetTester tester, String name) async {
  if (_captureDir.isEmpty) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('k3-capture')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      Directory(_captureDir).createSync(recursive: true);
      File(
        '$_captureDir/$name.png',
      ).writeAsBytesSync(bytes!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
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
      key: const ValueKey('k3-capture'),
      child: host(
        home,
        size: size,
        textScale: textScale,
        reduceMotion: reduceMotion,
      ),
    ),
  );
  await pumpUntilPhoneField(tester);
  await tester.pump(const Duration(milliseconds: 300));
  expectNoOverflow(tester, name);
  await captureCurrent(tester, name);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets(
    'register and recovery fit phones, text scales, and reduced motion',
    (tester) async {
      for (final size in _sizes) {
        for (final scale in _scales) {
          for (final reduce in <bool>[false, true]) {
            setView(tester, size);
            await tester.pumpWidget(
              host(
                const RegisterPage(),
                size: size,
                textScale: scale,
                reduceMotion: reduce,
              ),
            );
            await tester.pump();
            expect(find.text('Create Account'), findsOneWidget);
            expect(find.text('Invite Code is Mandatory'), findsOneWidget);
            expect(
              find.text(
                'A valid invite code is required to create an account.',
              ),
              findsOneWidget,
            );
            expect(find.text('+91'), findsOneWidget);
            await tester.ensureVisible(find.text('Create Account'));
            expectNoSmsEmailOtpCopy(tester);
            expectNoOverflow(tester, 'register $size x$scale reduce=$reduce');

            await tester.pumpWidget(
              host(
                const ForgotPasswordPage(),
                size: size,
                textScale: scale,
                reduceMotion: reduce,
              ),
            );
            await pumpUntilPhoneField(tester);
            expect(find.text('Customer Support'), findsOneWidget);
            expect(find.text('Password recovery'), findsOneWidget);
            expect(find.text('+91'), findsOneWidget);
            await tester.ensureVisible(find.text('Customer Support'));
            expectNoSmsEmailOtpCopy(tester);
            expectNoOverflow(tester, 'recovery $size x$scale reduce=$reduce');
          }
        }
      }
      await disposeTree(tester);
    },
  );

  testWidgets('login Create Account and Forgot Password stay fully readable', (
    tester,
  ) async {
    setView(tester, const Size(320, 568));
    await tester.pumpWidget(
      host(
        LoginPage(onSignedIn: (_) {}),
        size: const Size(320, 568),
        textScale: 1.5,
        reduceMotion: true,
      ),
    );
    await tester.pump();
    expect(find.text('Forgot Password?'), findsOneWidget);
    expect(find.text('Create Account'), findsOneWidget);
    final createAccount = tester.widget<Text>(find.text('Create Account'));
    expect(createAccount.overflow, isNot(TextOverflow.ellipsis));
    expectNoOverflow(tester, 'login 320 x1.5 links');
    await disposeTree(tester);
  });

  testWidgets('register keeps typed phone after country switch', (
    tester,
  ) async {
    setView(tester, const Size(390, 844));
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('k3-capture'),
        child: host(const RegisterPage(), reduceMotion: true),
      ),
    );
    await tester.enterText(find.byType(TextField).at(0), '9876543210');
    await tester.pump();
    phoneField(tester).onCountryChanged(Country.parse('AU'));
    await tester.pump();
    expect(find.text('9876543210'), findsOneWidget);
    expect(find.text('+61'), findsOneWidget);
    expect(find.text(Country.parse('AU').flagEmoji), findsOneWidget);
    expect(find.byTooltip('Australia flag, country code +61'), findsOneWidget);
    expect(phoneField(tester).country.countryCode, 'AU');
    expectNoSmsEmailOtpCopy(tester);
    await captureCurrent(tester, 'register-phone-switch-retained');
    await disposeTree(tester);
  });

  testWidgets('recovery country list shows flags names and dial codes', (
    tester,
  ) async {
    setView(tester, const Size(390, 844));
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('k3-capture'),
        child: host(const ForgotPasswordPage(), reduceMotion: true),
      ),
    );
    await pumpUntilPhoneField(tester);
    expect(find.text('+91'), findsOneWidget);
    await tester.tap(find.byTooltip('India flag, country code +91'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(CountryFlagGlyph), findsWidgets);
    expect(find.textContaining('India'), findsWidgets);
    expect(find.textContaining('+91'), findsWidgets);
    expect(find.textContaining('Afghanistan'), findsWidgets);
    expectNoSmsEmailOtpCopy(tester);
    expectNoOverflow(tester, 'recovery country list');
    await captureCurrent(tester, 'recovery-country-list');
    await tester.tap(find.text('Australia').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('+61'), findsOneWidget);
    expect(find.text(Country.parse('AU').flagEmoji), findsWidgets);
    await disposeTree(tester);
  });

  testWidgets('login and register request fields stay the same', (
    tester,
  ) async {
    setView(tester, const Size(390, 2000));
    late Map<String, dynamic> loginBody;
    late Map<String, dynamic> registerBody;
    await http.runWithClient(
      () async {
        await tester.pumpWidget(host(LoginPage(onSignedIn: (_) {})));
        await tester.enterText(find.byType(TextField).at(0), '9876543210');
        await tester.enterText(find.byType(TextField).at(1), 'password1');
        await tester.tap(find.text('Login'));
        await tester.pump();
        await tester.pump();
        await disposeTree(tester);

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
        await tester.ensureVisible(
          find.widgetWithText(FilledButton, 'Sign Up'),
        );
        await tester.tap(find.widgetWithText(FilledButton, 'Sign Up'));
        await tester.pump();
        await tester.pump();
        await disposeTree(tester);
      },
      () {
        return MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          if (request.url.path == '/auth/login') {
            loginBody = body;
            return http.Response(
              jsonEncode({'message': 'Invalid account or password'}),
              401,
            );
          }
          registerBody = body;
          return http.Response(
            jsonEncode({'message': 'Invalid invite code'}),
            400,
          );
        });
      },
    );
    expect(loginBody.keys.toSet(), {'phone', 'password'});
    expect(loginBody.containsKey('countryCode'), isFalse);
    expect(loginBody.containsKey('smsOtp'), isFalse);
    expect(loginBody.containsKey('verificationCode'), isFalse);
    expect(registerBody.keys.toSet(), {'phone', 'password', 'inviteCode'});
    expect(registerBody.containsKey('countryCode'), isFalse);
    expect(registerBody.containsKey('smsOtp'), isFalse);
  });

  testWidgets('render K.3 native text-scale variants', (tester) async {
    for (final size in _sizes) {
      await captureScreen(
        tester,
        'register-title-${size.width.toInt()}',
        size,
        const RegisterPage(),
      );
    }
    await captureScreen(
      tester,
      'register-text-scale-1.3',
      const Size(390, 844),
      const RegisterPage(),
      textScale: 1.3,
    );
    await captureScreen(
      tester,
      'register-text-scale-1.5',
      const Size(390, 844),
      const RegisterPage(),
      textScale: 1.5,
    );
    await captureScreen(
      tester,
      'recovery-text-scale-1.3',
      const Size(390, 844),
      const ForgotPasswordPage(),
      textScale: 1.3,
    );
    await captureScreen(
      tester,
      'recovery-text-scale-1.5',
      const Size(390, 844),
      const ForgotPasswordPage(),
      textScale: 1.5,
    );
    await captureScreen(
      tester,
      'login-text-scale-1.5-320',
      const Size(320, 568),
      LoginPage(onSignedIn: (_) {}),
      textScale: 1.5,
    );
    await disposeTree(tester);
  });
}
