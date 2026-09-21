import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:india_trading_app/pages/account_security_page.dart';
import 'package:india_trading_app/pages/account_settings_page.dart';
import 'package:india_trading_app/pages/legal_page.dart';
import 'package:india_trading_app/pages/login_page.dart';
import 'package:india_trading_app/pages/notifications_page.dart';
import 'package:india_trading_app/pages/support_chat_page.dart';
import 'package:india_trading_app/services/auth_service.dart';
import 'package:india_trading_app/services/client_account_service.dart';
import 'package:india_trading_app/services/session_expiry_service.dart';
import 'package:india_trading_app/theme/app_theme.dart';
import 'package:india_trading_app/widgets/profile_identity.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget host(
  Widget child, {
  Size size = const Size(390, 844),
  double textScale = 1,
  bool reduceMotion = false,
  double keyboard = 0,
}) {
  return MaterialApp(
    theme: AppTheme.light(),
    builder: (context, content) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        size: size,
        textScaler: TextScaler.linear(textScale),
        disableAnimations: reduceMotion,
        accessibleNavigation: reduceMotion,
        viewInsets: EdgeInsets.only(bottom: keyboard),
      ),
      child: content!,
    ),
    home: child,
  );
}

void setView(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

class J3AccountFake extends ClientAccountService {
  J3AccountFake({
    this.profileData,
    this.banksData,
    this.preferencesData,
    this.notify,
  });

  Map<String, dynamic>? profileData;
  List<Map<String, dynamic>>? banksData;
  Map<String, dynamic>? preferencesData;
  List<Map<String, dynamic>>? notify;
  Object? profileError;
  Object? updateError;
  Object? banksError;
  Object? preferencesError;
  Object? notifyError;
  Object? passwordError;
  Completer<void>? passwordGate;
  Completer<Map<String, dynamic>>? profileGate;
  final savedNames = <String>[];
  final passwordCalls = <List<String>>[];
  final preferenceUpdates = <Map<String, dynamic>>[];
  var preferenceCalls = 0;

  @override
  Future<Map<String, dynamic>> profile() async {
    if (profileGate != null) return profileGate!.future;
    if (profileError != null) throw profileError!;
    return profileData ??
        {
          'fullName': 'Test Client',
          'phone': '9876543210',
          'status': 'ACTIVE',
          'clientTier': 'GOLD',
          'createdAt': '2026-01-15T10:00:00.000Z',
          'account': {'accountNumber': 'ACCOUNT-123'},
        };
  }

  @override
  Future<Map<String, dynamic>> updateProfile(String name) async {
    savedNames.add(name);
    if (updateError != null) throw updateError!;
    return {'fullName': name};
  }

  @override
  Future<List<Map<String, dynamic>>> banks() async {
    if (banksError != null) throw banksError!;
    return banksData ??
        [
          {
            'id': 'bank-1',
            'bankName': 'HDFC Bank',
            'accountNumber': '123456789012',
            'ifscCode': 'HDFC0001234',
            'accountHolder': 'Test Client',
            'status': '',
          },
        ];
  }

  @override
  Future<Map<String, dynamic>> preferences() async {
    if (preferencesError != null) throw preferencesError!;
    return preferencesData ??
        {
          'orderNotifications': false,
          'accountNotifications': true,
          'supportNotifications': false,
        };
  }

  @override
  Future<void> updatePreferences(Map<String, dynamic> data) async {
    preferenceCalls += 1;
    preferenceUpdates.add(Map<String, dynamic>.from(data));
  }

  @override
  Future<List<Map<String, dynamic>>> notifications() async {
    if (notifyError != null) throw notifyError!;
    return notify ?? const [];
  }

  @override
  Future<void> changePassword(String current, String next) async {
    passwordCalls.add([current, next]);
    if (passwordGate != null) await passwordGate!.future;
    if (passwordError != null) throw passwordError!;
  }
}

void expectNoSensitiveLeaks(WidgetTester tester) {
  expect(find.textContaining('cookie='), findsNothing);
  expect(find.textContaining('Bearer '), findsNothing);
  expect(find.textContaining('accessToken'), findsNothing);
  expect(find.textContaining('SMS OTP'), findsNothing);
  expect(find.textContaining('Aadhaar OTP'), findsNothing);
  expect(find.textContaining('customer manager'), findsNothing);
  expect(find.textContaining('Relationship Manager'), findsNothing);
  expect(find.textContaining('VIP service'), findsNothing);
  expect(tester.takeException(), isNull);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    SessionExpiryService().onExpired = null;
  });

  test('bank and profile helpers mask or mark unavailable', () {
    expect(maskBankAccountNumber('123456789012', revealed: false), '•••• 9012');
    expect(maskBankAccountNumber('', revealed: false), 'Unavailable');
    expect(maskIfscCode('HDFC0001234', revealed: false), 'HDFC••••');
    expect(maskIfscCode('', revealed: false), 'Unavailable');
    expect(displayOrUnavailable(null), 'Unavailable');
    expect(displayOrUnavailable('--'), 'Unavailable');
    expect(maskAccountPhone('9876543210'), isNot(contains('9876543210')));
  });

  testWidgets('profile loading error retry and partial fields', (tester) async {
    setView(tester, const Size(390, 844));
    final service = J3AccountFake()..profileError = const AuthException('offline');
    await tester.pumpWidget(
      host(
        AccountSettingsPage(section: 'profile', accountService: service),
        reduceMotion: true,
      ),
    );
    expect(find.text('Loading account'), findsOneWidget);
    expect(find.byIcon(Icons.hourglass_empty_rounded), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('Unable to load account'), findsOneWidget);
    service.profileError = null;
    service.profileData = {
      'fullName': 'Patel',
      'phone': '',
      'status': '',
      'clientTier': 'UNKNOWN',
      'account': {'accountNumber': ''},
    };
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Unavailable'), findsWidgets);
    expect(find.text('UNKNOWN'), findsNothing);
    expect(find.text('Save changes'), findsOneWidget);
    expectNoSensitiveLeaks(tester);
  });

  testWidgets('profile save failure keeps the typed name', (tester) async {
    setView(tester, const Size(390, 844));
    final service = J3AccountFake();
    await tester.pumpWidget(
      host(
        AccountSettingsPage(section: 'profile', accountService: service),
        reduceMotion: true,
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Kept Name');
    service.updateError = const AuthException('Unable to save profile');
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'Kept Name');
    expect(find.text('Unable to save profile'), findsOneWidget);
  });

  testWidgets('bank missing fields stay unavailable and numbers stay masked', (
    tester,
  ) async {
    setView(tester, const Size(414, 896));
    final service = J3AccountFake(
      banksData: [
        {
          'id': 'bank-2',
          'bankName': '',
          'accountNumber': '',
          'ifscCode': '',
          'accountHolder': '',
        },
      ],
    );
    await tester.pumpWidget(
      host(
        AccountSettingsPage(section: 'banks', accountService: service),
        reduceMotion: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Unavailable'), findsWidgets);
    expect(find.textContaining('123456789012'), findsNothing);
    expect(find.textContaining('This is not a completed bank verification'), findsOneWidget);
    expect(find.byTooltip('Copy'), findsNothing);
    expectNoSensitiveLeaks(tester);
  });

  testWidgets('password show hide success failure and no repeat submit', (
    tester,
  ) async {
    setView(tester, const Size(390, 844));
    final service = J3AccountFake()
      ..passwordError = const AuthException('Current password is incorrect');
    await tester.pumpWidget(
      host(AccountSecurityPage(accountService: service), reduceMotion: true),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Show'), findsWidgets);
    await tester.tap(find.byTooltip('Show').first);
    await tester.pump();
    expect(find.byTooltip('Hide'), findsWidgets);

    await tester.enterText(find.byType(TextFormField).at(0), 'oldpass12');
    await tester.enterText(find.byType(TextFormField).at(1), 'newpass34');
    await tester.enterText(find.byType(TextFormField).at(2), 'newpass34');
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(find.text('Current password is incorrect'), findsOneWidget);
    expect(
      tester.widget<TextFormField>(find.byType(TextFormField).first).controller!.text,
      'oldpass12',
    );
    expect(service.passwordCalls, [
      ['oldpass12', 'newpass34'],
    ]);

    service.passwordError = null;
    service.passwordGate = Completer<void>();
    await tester.tap(find.text('Save changes'));
    await tester.pump();
    await tester.tap(find.text('Save changes'));
    await tester.pump();
    expect(service.passwordCalls, hasLength(2));
    service.passwordGate!.complete();
    await tester.pump();
    await tester.pump();
    expect(find.text('Password changed. Please sign in again'), findsOneWidget);
    expect(service.passwordCalls, hasLength(2));
  });

  testWidgets('session expiry notice stays on the sign-in path', (tester) async {
    setView(tester, const Size(390, 844));
    await tester.pumpWidget(
      host(
        LoginPage(
          notice: 'Your session has expired. Please sign in again.',
          onSignedIn: (_) {},
        ),
        reduceMotion: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Your session has expired. Please sign in again.'), findsOneWidget);
    expect(find.textContaining('Welcome Back'), findsOneWidget);
    expectNoSensitiveLeaks(tester);
  });

  testWidgets('notification preferences save only after the server accepts', (
    tester,
  ) async {
    setView(tester, const Size(390, 844));
    final service = J3AccountFake();
    await tester.pumpWidget(
      host(
        AccountSettingsPage(section: 'preferences', accountService: service),
        reduceMotion: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('These switches save to the server. A failed change is not kept as saved.'), findsOneWidget);
    await tester.tap(find.text('Order notifications'));
    await tester.pumpAndSettle();
    expect(service.preferenceCalls, 1);
    expect(service.preferenceUpdates.first['orderNotifications'], isTrue);
  });

  testWidgets('legal document stays scrollable with version text', (tester) async {
    setView(tester, const Size(320, 568));
    await tester.pumpWidget(
      host(
        const LegalPage(title: 'Privacy'),
        size: const Size(320, 568),
        textScale: 1.5,
        reduceMotion: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Version 1.0'), findsOneWidget);
    expect(find.byType(Scrollable), findsWidgets);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -240));
    await tester.pumpAndSettle();
    expect(find.textContaining('SMS OTP'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('support stays populated without live-agent or ticket claims', (
    tester,
  ) async {
    setView(tester, const Size(390, 844));
    await tester.pumpWidget(host(const SupportChatPage(), reduceMotion: true));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.textContaining('Online Customer Service'), findsOneWidget);
    expect(find.textContaining('ticket'), findsNothing);
    expect(find.textContaining('VIP'), findsNothing);
    expect(find.text('Online now'), findsNothing);
    expectNoSensitiveLeaks(tester);
  });

  testWidgets('notifications error is not a blank screen', (tester) async {
    setView(tester, const Size(390, 844));
    final service = J3AccountFake()..notifyError = Exception('offline');
    await tester.pumpWidget(
      host(NotificationsPage(accountService: service), reduceMotion: true),
    );
    expect(find.text('Loading notifications'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('Unable to load notifications'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('leaving during delayed profile load does not throw', (tester) async {
    final service = J3AccountFake()
      ..profileGate = Completer<Map<String, dynamic>>();
    await tester.pumpWidget(
      host(AccountSettingsPage(section: 'profile', accountService: service)),
    );
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    service.profileGate!.complete({'fullName': 'Late'});
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile and security fit 320 390 414 768 and text scale 1.5', (
    tester,
  ) async {
    const sizes = [
      Size(320, 568),
      Size(390, 844),
      Size(414, 896),
      Size(768, 1024),
    ];
    for (final size in sizes) {
      setView(tester, size);
      final service = J3AccountFake();
      await tester.pumpWidget(
        host(
          AccountSettingsPage(section: 'profile', accountService: service),
          size: size,
          textScale: size.width == 320 ? 1.5 : 1.3,
          reduceMotion: true,
          keyboard: size.width == 390 ? 280 : 0,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('ACCOUNT-123'), findsOneWidget);
      expect(find.textContaining('******3210'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        host(
          AccountSettingsPage(section: 'banks', accountService: service),
          size: size,
          textScale: 1.3,
          reduceMotion: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('123456789012'), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        host(
          AccountSecurityPage(accountService: service),
          size: size,
          textScale: 1.3,
          reduceMotion: true,
          keyboard: 240,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Save changes'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}
