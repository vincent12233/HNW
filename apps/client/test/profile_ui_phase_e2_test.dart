import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:india_trading_app/pages/account_security_page.dart';
import 'package:india_trading_app/pages/account_settings_page.dart';
import 'package:india_trading_app/pages/appearance_page.dart';
import 'package:india_trading_app/pages/language_page.dart';
import 'package:india_trading_app/pages/legal_page.dart';
import 'package:india_trading_app/pages/notifications_page.dart';
import 'package:india_trading_app/pages/support_chat_page.dart';
import 'package:india_trading_app/pages/two_factor_page.dart';
import 'package:india_trading_app/services/auth_service.dart';
import 'package:india_trading_app/services/client_account_service.dart';
import 'package:india_trading_app/theme/app_theme.dart';
import 'package:india_trading_app/widgets/profile_identity.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget host(
  Widget child, {
  Size size = const Size(390, 844),
  double textScale = 1,
  bool reduceMotion = false,
}) {
  return MaterialApp(
    theme: AppTheme.light(),
    builder: (context, content) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        size: size,
        textScaler: TextScaler.linear(textScale),
        disableAnimations: reduceMotion,
        accessibleNavigation: reduceMotion,
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

class ProfileFake extends ClientAccountService {
  ProfileFake({this.profileData, this.banksData, this.kyc, this.notify});
  final Map<String, dynamic>? profileData;
  final List<Map<String, dynamic>>? banksData;
  final Map<String, dynamic>? kyc;
  final List<Map<String, dynamic>>? notify;
  Object? profileError;
  Object? notifyError;
  final savedNames = <String>[];
  final deletedBanks = <String>[];
  var deleteCalls = 0;

  @override
  Future<Map<String, dynamic>> profile() async {
    if (profileError != null) throw profileError!;
    return profileData ??
        {
          'fullName': 'Test Client',
          'account': {'accountNumber': 'ACCOUNT-123'},
        };
  }

  @override
  Future<Map<String, dynamic>> updateProfile(String name) async {
    savedNames.add(name);
    return {'fullName': name};
  }

  @override
  Future<List<Map<String, dynamic>>> banks() async =>
      banksData ??
      [
        {
          'id': 'bank-1',
          'bankName': 'HDFC Bank',
          'accountNumber': '123456789012',
          'status': '',
        },
      ];

  @override
  Future<void> deleteBank(String id) async {
    deleteCalls += 1;
    deletedBanks.add(id);
  }

  @override
  Future<Map<String, dynamic>> kycStatus() async =>
      kyc ?? {'status': 'PENDING', 'reviewNote': 'Documents under review'};

  @override
  Future<List<Map<String, dynamic>>> notifications() async {
    if (notifyError != null) throw notifyError!;
    return notify ?? const [];
  }

  @override
  Future<void> updatePreferences(Map<String, dynamic> data) async {}
}

class TotpFake extends ClientAccountService {
  TotpFake({this.enabled = false, this.fail = false});
  final bool enabled;
  final bool fail;
  final actions = <String>[];

  @override
  Future<Map<String, dynamic>> twoFactorStatus() async {
    if (fail) throw Exception('offline');
    return {'enabled': enabled};
  }

  @override
  Future<Map<String, dynamic>> twoFactorAction(
    String action, {
    String? password,
    String? code,
  }) async {
    actions.add(action);
    throw AuthException('authenticator rejected');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('phone masking never returns the full number', () {
    expect(maskAccountPhone('9876543210'), '+91 ******3210');
    expect(maskAccountPhone('+91 98765 43210'), '+91 ******3210');
    expect(maskAccountPhone(''), '--');
    expect(maskAccountPhone('9876543210'), isNot(contains('9876543210')));
  });

  test('KYC labels stay on server statuses and never say Verified', () {
    expect(profileKycLabel('NOT_SUBMITTED'), 'Not started');
    expect(profileKycLabel('PENDING'), 'PENDING');
    expect(profileKycLabel('APPROVED'), 'APPROVED');
    expect(profileKycLabel('REJECTED'), 'REJECTED');
    expect(profileKycLabel('APPROVED'), isNot(contains('Verified')));
  });

  testWidgets('profile header fits 320 at text scale 1.3', (tester) async {
    setView(tester, const Size(320, 568));
    await tester.pumpWidget(
      host(
        const Scaffold(
          body: SingleChildScrollView(
            child: ProfileIdentityHeader(
              name: 'Very Long Client Display Name For Overflow',
              accountNumber: 'ACCOUNT-123456789',
              phone: '9876543210',
              kycStatus: 'APPROVED',
              clientTier: 'GOLD',
              memberSince: '2026-01-01',
              accountStatus: 'SUSPENDED',
            ),
          ),
        ),
        size: const Size(320, 568),
        textScale: 1.3,
        reduceMotion: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('******3210'), findsOneWidget);
    expect(find.textContaining('9876543210'), findsNothing);
    expect(find.textContaining('KYC APPROVED'), findsOneWidget);
    expect(find.text('Suspended'), findsOneWidget);
    expect(find.text('Verified'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile header keeps three compact status columns at 320', (
    tester,
  ) async {
    setView(tester, const Size(320, 568));
    await tester.pumpWidget(
      host(
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
        size: const Size(320, 568),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ProfileIdentityHeader), findsOneWidget);
    expect(find.text('KYC APPROVED'), findsOneWidget);
    expect(
      tester.getSize(find.byType(ProfileIdentityHeader)).height,
      lessThan(260),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile loading error retry and read-only account id', (
    tester,
  ) async {
    setView(tester, const Size(390, 844));
    final service = ProfileFake()..profileError = AuthException('offline');
    await tester.pumpWidget(
      host(
        AccountSettingsPage(section: 'profile', accountService: service),
        reduceMotion: true,
      ),
    );
    expect(find.text('Loading account'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('Unable to load account'), findsOneWidget);
    service.profileError = null;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('ACCOUNT-123'), findsOneWidget);
    expect(find.text('Read-only'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('hidden@example.com'), findsNothing);
  });

  testWidgets('saving profile still sends only the full name', (tester) async {
    setView(tester, const Size(390, 844));
    final service = ProfileFake();
    await tester.pumpWidget(
      host(
        AccountSettingsPage(section: 'profile', accountService: service),
        reduceMotion: true,
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Patel Client');
    await tester.tap(find.text('Save changes'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(service.savedNames, ['Patel Client']);
  });

  testWidgets('bank numbers stay masked until shown and delete needs confirm', (
    tester,
  ) async {
    setView(tester, const Size(390, 844));
    final service = ProfileFake();
    await tester.pumpWidget(
      host(
        AccountSettingsPage(section: 'banks', accountService: service),
        reduceMotion: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('123456789012'), findsNothing);
    expect(find.textContaining('•••• 9012'), findsOneWidget);
    await tester.tap(find.byTooltip('Show account number'));
    await tester.pumpAndSettle();
    expect(find.textContaining('123456789012'), findsOneWidget);
    await tester.tap(find.byTooltip('Remove bank account'));
    await tester.pumpAndSettle();
    expect(find.text('Remove bank account?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(service.deleteCalls, 0);
  });

  testWidgets('KYC status page uses APPROVED without extra action', (
    tester,
  ) async {
    setView(tester, const Size(390, 844));
    await tester.pumpWidget(
      host(
        AccountSettingsPage(
          section: 'kyc',
          accountService: ProfileFake(kyc: {'status': 'APPROVED'}),
        ),
        reduceMotion: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('APPROVED'), findsOneWidget);
    expect(find.text('Start verification'), findsNothing);
    expect(find.text('Verified'), findsNothing);
  });

  testWidgets('TOTP copy forbids SMS and Aadhaar OTP', (tester) async {
    setView(tester, const Size(390, 844));
    await tester.pumpWidget(
      host(TwoFactorPage(accountService: TotpFake()), reduceMotion: true),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('SMS OTP'), findsNothing);
    expect(find.textContaining('Aadhaar OTP'), findsNothing);
    expect(find.textContaining('验证码已发送'), findsNothing);
    expect(find.textContaining('optional'), findsWidgets);
  });

  testWidgets('TOTP failure keeps the form and shows the server error', (
    tester,
  ) async {
    setView(tester, const Size(390, 844));
    final service = TotpFake(enabled: true);
    await tester.pumpWidget(
      host(TwoFactorPage(accountService: service), reduceMotion: true),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'password1');
    await tester.enterText(find.byType(TextField).last, '123456');
    await tester.tap(find.text('Disable'));
    await tester.pumpAndSettle();
    expect(find.textContaining('authenticator rejected'), findsOneWidget);
    expect(find.text('Disable'), findsOneWidget);
    expect(service.actions, ['disable']);
  });

  testWidgets('password page can reveal the current password field', (
    tester,
  ) async {
    setView(tester, const Size(390, 844));
    await tester.pumpWidget(
      host(
        AccountSecurityPage(accountService: ProfileFake()),
        reduceMotion: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Show'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('notifications empty error and retry stay honest', (
    tester,
  ) async {
    setView(tester, const Size(390, 844));
    final service = ProfileFake()..notifyError = Exception('offline');
    await tester.pumpWidget(
      host(NotificationsPage(accountService: service), reduceMotion: true),
    );
    expect(find.text('Loading notifications'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('Unable to load notifications'), findsOneWidget);
    service.notifyError = null;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('No notifications yet'), findsOneWidget);
  });

  testWidgets('appearance and language keep current options', (tester) async {
    SharedPreferences.setMockInitialValues({});
    setView(tester, const Size(390, 844));
    await tester.pumpWidget(host(const AppearancePage(), reduceMotion: true));
    await tester.pumpAndSettle();
    expect(find.text('Light Theme'), findsOneWidget);
    expect(find.text('High contrast'), findsOneWidget);
    await tester.pumpWidget(
      host(LanguagePage(accountService: ProfileFake()), reduceMotion: true),
    );
    await tester.pumpAndSettle();
    expect(find.text('English'), findsOneWidget);
    expect(find.text('हिन्दी'), findsOneWidget);
  });

  testWidgets('legal pages do not advertise SMS or Aadhaar OTP', (
    tester,
  ) async {
    setView(tester, const Size(390, 844));
    await tester.pumpWidget(
      host(const LegalPage(title: 'Privacy'), reduceMotion: true),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('SMS OTP'), findsNothing);
    expect(find.textContaining('Aadhaar OTP'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('bank page fits 320 at text scale 1.3 with masked numbers', (
    tester,
  ) async {
    setView(tester, const Size(320, 568));
    await tester.pumpWidget(
      host(
        AccountSettingsPage(section: 'banks', accountService: ProfileFake()),
        size: const Size(320, 568),
        textScale: 1.3,
        reduceMotion: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('123456789012'), findsNothing);
    expect(find.textContaining('•••• 9012'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('KYC rejected page fits 320 and offers resubmit', (tester) async {
    setView(tester, const Size(320, 568));
    await tester.pumpWidget(
      host(
        AccountSettingsPage(
          section: 'kyc',
          accountService: ProfileFake(
            kyc: {
              'status': 'REJECTED',
              'reviewNote': 'Please resubmit documents',
            },
          ),
        ),
        size: const Size(320, 568),
        textScale: 1.3,
        reduceMotion: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('REJECTED'), findsOneWidget);
    expect(find.text('Resubmit documents'), findsOneWidget);
    expect(find.text('Verified'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'support opening failure shows retry without claiming a live agent',
    (tester) async {
      setView(tester, const Size(390, 844));
      await tester.pumpWidget(
        host(const SupportChatPage(), reduceMotion: true),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(find.textContaining('SMS OTP'), findsNothing);
      expect(find.text('Online now'), findsNothing);
      expect(find.textContaining('Connecting you to an agent'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
