import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:india_trading_app/pages/account_security_page.dart';
import 'package:india_trading_app/pages/account_settings_page.dart';
import 'package:india_trading_app/pages/legal_page.dart';
import 'package:india_trading_app/pages/login_page.dart';
import 'package:india_trading_app/pages/notifications_page.dart';
import 'package:india_trading_app/pages/support_chat_page.dart';
import 'package:india_trading_app/services/auth_service.dart';
import 'package:india_trading_app/theme/app_theme.dart';
import 'package:india_trading_app/widgets/profile_identity.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'profile_security_j3_test.dart';

const _output = String.fromEnvironment('UI_CAPTURE_DIR');

Widget _host(
  Size size,
  Widget home, {
  double scale = 1,
  double keyboard = 0,
}) {
  return MaterialApp(
    theme: AppTheme.light(),
    debugShowCheckedModeBanner: false,
    builder: (context, content) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        size: size,
        textScaler: TextScaler.linear(scale),
        disableAnimations: true,
        viewInsets: EdgeInsets.only(bottom: keyboard),
      ),
      child: content!,
    ),
    home: home,
  );
}

Future<void> _capture(
  WidgetTester tester,
  String name,
  Size size,
  Widget home, {
  bool settle = true,
  double scale = 1,
  double keyboard = 0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  SharedPreferences.setMockInitialValues({});
  FlutterSecureStorage.setMockInitialValues({});
  await tester.pumpWidget(
    RepaintBoundary(
      key: const ValueKey('capture'),
      child: _host(size, home, scale: scale, keyboard: keyboard),
    ),
  );
  if (settle) {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  } else {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('capture')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory(_output).createSync(recursive: true);
    File('$_output/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
  await tester.pumpWidget(const SizedBox.shrink());
}

void main() {
  final skip = _output.isEmpty;
  const sizes = <String, Size>{
    '320': Size(320, 568),
    '390': Size(390, 844),
    '414': Size(414, 896),
    '768': Size(768, 1024),
  };

  test('writes j3 profile screenshots', () async {}, skip: skip);

  if (skip) return;

  for (final entry in sizes.entries) {
    testWidgets('profile states ${entry.key}', (tester) async {
      final loading = Completer<Map<String, dynamic>>();
      await _capture(
        tester,
        'profile-loading-${entry.key}',
        entry.value,
        AccountSettingsPage(
          section: 'profile',
          accountService: J3AccountFake()..profileGate = loading,
        ),
        settle: false,
      );
      loading.complete({'fullName': 'Late'});

      await _capture(
        tester,
        'profile-error-${entry.key}',
        entry.value,
        AccountSettingsPage(
          section: 'profile',
          accountService: J3AccountFake()
            ..profileError = const AuthException('offline'),
        ),
      );
      await _capture(
        tester,
        'profile-partial-${entry.key}',
        entry.value,
        AccountSettingsPage(
          section: 'profile',
          accountService: J3AccountFake(
            profileData: {
              'fullName': 'Patel',
              'phone': '',
              'status': '',
              'clientTier': '',
            },
          ),
        ),
      );
      await _capture(
        tester,
        'profile-loaded-${entry.key}',
        entry.value,
        AccountSettingsPage(
          section: 'profile',
          accountService: J3AccountFake(),
        ),
      );
      await _capture(
        tester,
        'profile-header-${entry.key}',
        entry.value,
        const Scaffold(
          body: SingleChildScrollView(
            child: ProfileIdentityHeader(
              name: 'Test Client',
              accountNumber: 'ACCOUNT-123',
              phone: '9876543210',
              kycStatus: 'APPROVED',
              clientTier: 'GOLD',
              memberSince: '2026-01-01',
              accountStatus: 'ACTIVE',
            ),
          ),
        ),
      );
    });

    testWidgets('bank security support ${entry.key}', (tester) async {
      await _capture(
        tester,
        'banks-empty-${entry.key}',
        entry.value,
        AccountSettingsPage(
          section: 'banks',
          accountService: J3AccountFake(banksData: const []),
        ),
      );
      await _capture(
        tester,
        'banks-masked-${entry.key}',
        entry.value,
        AccountSettingsPage(
          section: 'banks',
          accountService: J3AccountFake(),
        ),
      );
      await _capture(
        tester,
        'security-${entry.key}',
        entry.value,
        AccountSecurityPage(accountService: J3AccountFake()),
      );
      await _capture(
        tester,
        'preferences-${entry.key}',
        entry.value,
        AccountSettingsPage(
          section: 'preferences',
          accountService: J3AccountFake(),
        ),
      );
      await _capture(
        tester,
        'notifications-empty-${entry.key}',
        entry.value,
        NotificationsPage(accountService: J3AccountFake()),
      );
      await _capture(
        tester,
        'notifications-error-${entry.key}',
        entry.value,
        NotificationsPage(
          accountService: J3AccountFake()..notifyError = Exception('offline'),
        ),
      );
      await _capture(
        tester,
        'legal-${entry.key}',
        entry.value,
        const LegalPage(title: 'Privacy'),
      );
      await _capture(
        tester,
        'support-${entry.key}',
        entry.value,
        const SupportChatPage(),
        settle: false,
      );
      await _capture(
        tester,
        'session-expired-${entry.key}',
        entry.value,
        LoginPage(
          notice: 'Your session has expired. Please sign in again.',
          onSignedIn: (_) {},
        ),
      );
    });
  }

  testWidgets('text scale and keyboard', (tester) async {
    const size = Size(390, 844);
    await _capture(
      tester,
      'profile-text-1.3-390',
      size,
      AccountSettingsPage(
        section: 'profile',
        accountService: J3AccountFake(),
      ),
      scale: 1.3,
    );
    await _capture(
      tester,
      'profile-text-1.5-390',
      size,
      AccountSettingsPage(
        section: 'profile',
        accountService: J3AccountFake(),
      ),
      scale: 1.5,
    );
    await _capture(
      tester,
      'profile-keyboard-390',
      size,
      AccountSettingsPage(
        section: 'profile',
        accountService: J3AccountFake(),
      ),
      keyboard: 280,
    );
    await _capture(
      tester,
      'legal-text-1.5-320',
      const Size(320, 568),
      const LegalPage(title: 'Terms'),
      scale: 1.5,
    );
    final loading = Completer<Map<String, dynamic>>();
    await _capture(
      tester,
      'profile-reduced-motion-390',
      size,
      AccountSettingsPage(
        section: 'profile',
        accountService: J3AccountFake()..profileGate = loading,
      ),
      settle: false,
    );
    loading.complete({'fullName': 'Late'});
  });
}
