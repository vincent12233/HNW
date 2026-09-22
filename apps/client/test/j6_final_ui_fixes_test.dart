import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:india_trading_app/pages/account_settings_page.dart';
import 'package:india_trading_app/services/auth_service.dart';
import 'package:india_trading_app/services/client_account_service.dart';
import 'package:india_trading_app/theme/app_theme.dart';
import 'package:india_trading_app/utils/number_formatters.dart';
import 'package:india_trading_app/widgets/profile_identity.dart';

const _captureDir = '/tmp/hnw-j6-final-fixes';

String compactInr(String value) =>
    value.replaceAll(RegExp(r'[\s\u00a0\u202f]'), '');

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

class RecFake extends ClientAccountService {
  RecFake({this.payload, this.error});

  final Map<String, dynamic>? payload;
  final Object? error;

  @override
  Future<Map<String, dynamic>> reconciliation() async {
    if (error != null) throw error!;
    return Map<String, dynamic>.from(payload ?? const {});
  }
}

Widget identity({
  String name = 'Test Client',
  String accountNumber = 'ACCOUNT-123',
  String kycStatus = 'APPROVED',
  String clientTier = 'GOLD',
  String accountStatus = 'ACTIVE',
}) {
  return Scaffold(
    body: SingleChildScrollView(
      child: ProfileIdentityHeader(
        name: name,
        accountNumber: accountNumber,
        phone: '9876543210',
        kycStatus: kycStatus,
        clientTier: clientTier,
        memberSince: '2026-01-01',
        accountStatus: accountStatus,
        onEdit: () {},
        onAvatarTap: () {},
      ),
    ),
  );
}

Future<void> capture(
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
      key: const ValueKey('j6-capture'),
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
  expect(tester.takeException(), isNull);
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('j6-capture')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory(_captureDir).createSync(recursive: true);
    File(
      '$_captureDir/$name.png',
    ).writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  test('formatPriceValue keeps real zero and rejects unknown amounts', () {
    expect(compactInr(formatPriceValue(0)), '₹0.00');
    expect(compactInr(formatPriceValue(0.0)), '₹0.00');
    expect(compactInr(formatPriceValue('0.00')), '₹0.00');
    expect(compactInr(formatPriceValue('0')), '₹0.00');
    expect(formatPriceValue(null), 'Unavailable');
    expect(formatPriceValue(''), 'Unavailable');
    expect(formatPriceValue('   '), 'Unavailable');
    expect(formatPriceValue('abc'), 'Unavailable');
    expect(formatPriceValue(double.nan), 'Unavailable');
    expect(formatPriceValue(double.infinity), 'Unavailable');
    expect(formatPriceValue(double.negativeInfinity), 'Unavailable');
    expect(parseFinitePrice(null), isNull);
    expect(parseFinitePrice({}), isNull);
    expect(compactInr(formatPriceValue(1234.5)), compactInr(formatPrice(1234.5)));
    expect(compactInr(formatPriceValue(-88.1)), compactInr(formatPrice(-88.1)));
    expect(formatPriceValue(-88.1), contains('-'));
    expect(formatPriceValue(-88.1), isNot(startsWith('+')));
    expect(formatPriceValue(null), isNot(compactInr(formatPrice(0))));
  });

  testWidgets('reconciliation preserves real zero on total and categories', (
    tester,
  ) async {
    setView(tester, const Size(390, 844));
    await tester.pumpWidget(
      host(
        AccountSettingsPage(
          section: 'reconciliation',
          accountService: RecFake(
            payload: {
              'totalAssets': 0,
              'categories': {'INST': '0.00', 'OTC': 0, 'IPO': 0.0},
              'balanced': true,
              'asOf': '2026-09-21',
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Unable to load account'), findsNothing);
    expect(find.text('Total assets'), findsOneWidget);
    expect(find.text('Unavailable'), findsNothing);
    final prices = tester.widgetList<Text>(find.textContaining('₹'));
    expect(prices, isNotEmpty);
    for (final price in prices) {
      expect(compactInr(price.data ?? ''), '₹0.00');
    }
    expect(find.text('INST'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reconciliation shows Unavailable for unknown total and categories', (
    tester,
  ) async {
    setView(tester, const Size(390, 844));
    await tester.pumpWidget(
      host(
        AccountSettingsPage(
          section: 'reconciliation',
          accountService: RecFake(
            payload: {
              'categories': {
                'INST': null,
                'OTC': '',
                'IPO': 'not-a-number',
                'OTHER': double.nan,
              },
              'balanced': false,
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Total assets'), findsOneWidget);
    expect(find.text('Unavailable'), findsWidgets);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text && compactInr(widget.data ?? '').contains('₹0.00'),
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('reconciliation load failure stays on error, not zero card', (
    tester,
  ) async {
    setView(tester, const Size(390, 844));
    await tester.pumpWidget(
      host(
        AccountSettingsPage(
          section: 'reconciliation',
          accountService: RecFake(
            error: const AuthException('offline'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Unable to load account'), findsOneWidget);
    expect(find.text('Total assets'), findsNothing);
    expect(find.text(formatPrice(0)), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile identity fits required sizes, scales, and long labels', (
    tester,
  ) async {
    const sizes = [
      Size(320, 568),
      Size(390, 844),
      Size(414, 896),
      Size(768, 1024),
    ];
    const scales = [1.0, 1.3, 1.5];
    const tiers = ['STANDARD', 'SILVER', 'GOLD', 'PLATINUM', '--'];
    const statuses = ['ACTIVE', 'SUSPENDED', 'DISABLED'];
    for (final size in sizes) {
      for (final scale in scales) {
        setView(tester, size);
        await tester.pumpWidget(
          host(
            identity(
              name: 'Very Long Client Display Name For Overflow Check',
              accountNumber: 'ACCOUNT-123456789012345',
              kycStatus: '',
              clientTier: tiers[(size.width ~/ 10 + scale.toInt()) % tiers.length],
              accountStatus: statuses[size.width ~/ 200 % statuses.length],
            ),
            size: size,
            textScale: scale,
            reduceMotion: true,
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull, reason: '$size scale $scale');
        expect(find.textContaining('KYC'), findsOneWidget);
        expect(find.textContaining('******3210'), findsOneWidget);
        expect(find.byTooltip('Edit profile'), findsOneWidget);
        expect(find.byTooltip('Edit profile photo'), findsOneWidget);
      }
    }
  });

  testWidgets('capture j6f reconciliation and identity harness shots', (
    tester,
  ) async {
    await capture(
      tester,
      'reconciliation-zero-390',
      const Size(390, 844),
      AccountSettingsPage(
        section: 'reconciliation',
        accountService: RecFake(
          payload: {
            'totalAssets': '0.00',
            'categories': {'INST': 0, 'OTC': 0, 'IPO': 0},
            'balanced': true,
            'asOf': '2026-09-21',
          },
        ),
      ),
    );
    await capture(
      tester,
      'reconciliation-unknown-390',
      const Size(390, 844),
      AccountSettingsPage(
        section: 'reconciliation',
        accountService: RecFake(
          payload: {
            'totalAssets': null,
            'categories': {'INST': '', 'OTC': 'abc', 'IPO': double.infinity},
          },
        ),
      ),
    );
    await capture(
      tester,
      'reconciliation-error-390',
      const Size(390, 844),
      AccountSettingsPage(
        section: 'reconciliation',
        accountService: RecFake(error: const AuthException('offline')),
      ),
    );

    const sizes = <String, Size>{
      '320': Size(320, 568),
      '390': Size(390, 844),
      '414': Size(414, 896),
      '768': Size(768, 1024),
    };
    for (final entry in sizes.entries) {
      await capture(
        tester,
        'identity-long-${entry.key}',
        entry.value,
        identity(
          name: 'Very Long Client Display Name For Overflow Check',
          accountNumber: 'ACCOUNT-123456789012345',
          kycStatus: 'UNKNOWN',
          clientTier: 'PLATINUM',
          accountStatus: 'SUSPENDED',
        ),
      );
    }
    await capture(
      tester,
      'identity-long-320-text-1.5',
      const Size(320, 568),
      identity(
        name: 'Very Long Client Display Name For Overflow Check',
        accountNumber: 'ACCOUNT-123456789012345',
        kycStatus: 'UNKNOWN',
        clientTier: 'PLATINUM',
        accountStatus: 'SUSPENDED',
      ),
      textScale: 1.5,
    );
    await capture(
      tester,
      'identity-short-390-reduced-motion',
      const Size(390, 844),
      identity(),
    );
  });
}
