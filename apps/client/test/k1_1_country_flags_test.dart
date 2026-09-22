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

void expectIndiaFlagAndCode(WidgetTester tester) {
  expect(find.byType(CountryFlagGlyph), findsWidgets);
  expect(find.text(Country.parse('IN').flagEmoji), findsWidgets);
  expect(find.text('+91'), findsOneWidget);
  expect(
    find.byTooltip('India flag, country code +91'),
    findsOneWidget,
  );
  expect(phoneField(tester).country.countryCode, 'IN');
}

void expectNoSmsEmailOtpCopy(WidgetTester tester) {
  expect(find.textContaining('SMS'), findsNothing);
  expect(find.textContaining('email verification'), findsNothing);
  expect(find.textContaining('email code'), findsNothing);
  expect(find.textContaining('Aadhaar OTP'), findsNothing);
  expect(find.textContaining('OTP'), findsNothing);
}

const _captureDir = '/tmp/hnw-k1-country-flags';

Future<void> captureCurrent(WidgetTester tester, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('k11-capture')),
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
      key: const ValueKey('k11-capture'),
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

  testWidgets('login shows India flag and +91 by default', (tester) async {
    setView(tester, const Size(390, 844));
    await tester.pumpWidget(host(LoginPage(onSignedIn: (_) {})));
    expectIndiaFlagAndCode(tester);
    expectNoSmsEmailOtpCopy(tester);
    await disposeTree(tester);
  });

  testWidgets('register shows India flag and +91 by default', (tester) async {
    setView(tester, const Size(390, 844));
    await tester.pumpWidget(host(const RegisterPage()));
    expectIndiaFlagAndCode(tester);
    expectNoSmsEmailOtpCopy(tester);
    await disposeTree(tester);
  });

  testWidgets('recovery shows India flag and +91 by default', (tester) async {
    setView(tester, const Size(390, 844));
    await tester.pumpWidget(host(const ForgotPasswordPage()));
    await pumpUntilPhoneField(tester);
    expectIndiaFlagAndCode(tester);
    expectNoSmsEmailOtpCopy(tester);
    await disposeTree(tester);
  });

  testWidgets('country list rows include flags and dial codes', (tester) async {
    setView(tester, const Size(390, 844));
    await tester.pumpWidget(host(LoginPage(onSignedIn: (_) {})));
    await tester.tap(find.byTooltip('India flag, country code +91'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(CountryFlagGlyph), findsWidgets);
    expect(find.text(Country.parse('IN').flagEmoji), findsWidgets);
    expect(find.textContaining('India'), findsWidgets);
    expect(find.textContaining('+91'), findsWidgets);
    expectNoSmsEmailOtpCopy(tester);
    await disposeTree(tester);
  });

  testWidgets('switching country updates flag name and dial without clearing phone', (
    tester,
  ) async {
    setView(tester, const Size(390, 844));
    await tester.pumpWidget(host(LoginPage(onSignedIn: (_) {})));
    await tester.enterText(find.byType(TextField).at(0), '9876543210');
    await tester.enterText(find.byType(TextField).at(1), 'password1');
    phoneField(tester).onCountryChanged(Country.parse('US'));
    await tester.pump();
    expect(find.text(Country.parse('US').flagEmoji), findsOneWidget);
    expect(find.text('+1'), findsOneWidget);
    expect(
      find.byTooltip('United States flag, country code +1'),
      findsOneWidget,
    );
    expect(find.text('9876543210'), findsOneWidget);
    expect(find.text('password1'), findsOneWidget);
    expect(phoneField(tester).country.countryCode, 'US');
    expect(phoneField(tester).country.name, 'United States');
    await disposeTree(tester);
  });

  testWidgets('login and register request fields stay the same', (tester) async {
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
        await tester.ensureVisible(find.widgetWithText(FilledButton, 'Sign Up'));
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
            return http.Response(jsonEncode({'message': 'Invalid credentials'}), 401);
          }
          registerBody = body;
          return http.Response(jsonEncode({'message': 'Invalid invite code'}), 400);
        });
      },
    );
    expect(loginBody.keys.toSet(), {'phone', 'password'});
    expect(loginBody.containsKey('smsOtp'), isFalse);
    expect(loginBody.containsKey('verificationCode'), isFalse);
    expect(registerBody.keys.toSet(), {'phone', 'password', 'inviteCode'});
    expect(registerBody.containsKey('smsOtp'), isFalse);
    expect(registerBody.containsKey('verificationCode'), isFalse);
  });

  testWidgets('invalid numbers still use the Indian mobile error', (
    tester,
  ) async {
    setView(tester, const Size(390, 844));
    await tester.pumpWidget(host(LoginPage(onSignedIn: (_) {})));
    await tester.enterText(find.byType(TextField).at(0), '123');
    await tester.enterText(find.byType(TextField).at(1), 'password1');
    await tester.tap(find.text('Login'));
    await tester.pump();
    expect(find.text('Enter a valid Indian mobile number'), findsOneWidget);
    expect(find.text('123'), findsOneWidget);
    await disposeTree(tester);
  });

  testWidgets('flag controls fit listed phones and text scales', (tester) async {
    const sizes = <Size>[
      Size(320, 568),
      Size(390, 844),
      Size(414, 896),
      Size(768, 1024),
    ];
    final pages = <String, Widget Function()>{
      'login': () => LoginPage(onSignedIn: (_) {}),
      'register': () => const RegisterPage(),
      'recovery': () => const ForgotPasswordPage(),
    };
    for (final size in sizes) {
      for (final scale in <double>[1, 1.3, 1.5]) {
        for (final entry in pages.entries) {
          setView(tester, size);
          await tester.pumpWidget(
            host(
              entry.value(),
              size: size,
              textScale: scale,
              reduceMotion: true,
            ),
          );
          await pumpUntilPhoneField(tester);
          expect(
            find.text('+91'),
            findsOneWidget,
            reason: '${entry.key} $size x$scale',
          );
          expect(find.byType(CountryFlagGlyph), findsWidgets);
          expectNoSmsEmailOtpCopy(tester);
          expect(
            tester.takeException(),
            isNull,
            reason: '${entry.key} $size x$scale',
          );
        }
      }
    }
    await disposeTree(tester);
  });

  testWidgets('write K.1.1 flag screenshots for visual review', (tester) async {
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
        'register-default-$tag',
        size,
        const RegisterPage(),
      );
      await captureScreen(
        tester,
        'recovery-default-$tag',
        size,
        const ForgotPasswordPage(),
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
      'recovery-reduced-motion-320x568',
      const Size(320, 568),
      const ForgotPasswordPage(),
    );

    setView(tester, const Size(390, 844));
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('k11-capture'),
        child: host(LoginPage(onSignedIn: (_) {}), reduceMotion: true),
      ),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextField).at(0), '9876543210');
    await tester.tap(find.byTooltip('India flag, country code +91'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await captureCurrent(tester, 'login-country-list-390x844');
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('k11-capture'),
        child: host(LoginPage(onSignedIn: (_) {}), reduceMotion: true),
      ),
    );
    await pumpUntilPhoneField(tester);
    await tester.enterText(find.byType(TextField).at(0), '9876543210');
    phoneField(tester).onCountryChanged(Country.parse('US'));
    await tester.pump();
    expect(find.text('9876543210'), findsOneWidget);
    expect(find.text('+1'), findsOneWidget);
    await captureCurrent(tester, 'login-switched-united-states-390x844');
    await disposeTree(tester);
  });
}
