import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:india_trading_app/theme/app_theme.dart';
import 'package:india_trading_app/widgets/membership_tier_badge.dart';
import 'package:india_trading_app/widgets/profile_identity.dart';

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

Widget profile({
  String tier = 'GOLD',
  String status = 'ACTIVE',
}) {
  return Scaffold(
    body: SingleChildScrollView(
      child: ProfileIdentityHeader(
        name: 'Test Client',
        accountNumber: 'ACCOUNT-123',
        phone: '9876543210',
        kycStatus: 'APPROVED',
        clientTier: tier,
        memberSince: '2026-01-01',
        accountStatus: status,
      ),
    ),
  );
}

void expectNoVipWriteCtas(WidgetTester tester) {
  expect(find.textContaining('Apply'), findsNothing);
  expect(find.textContaining('申请'), findsNothing);
  expect(find.textContaining('Upgrade'), findsNothing);
  expect(find.textContaining('升级'), findsNothing);
  expect(find.textContaining('service request'), findsNothing);
  expect(find.textContaining('工单'), findsNothing);
  expect(find.textContaining('Relationship Manager'), findsNothing);
  expect(find.textContaining('客户经理'), findsNothing);
  expect(find.textContaining('OTP'), findsNothing);
  expect(tester.takeException(), isNull);
}

void main() {
  testWidgets('profile shows own VIP tier without fake amounts', (tester) async {
    setView(tester, const Size(390, 844));
    await tester.pumpWidget(host(profile(), reduceMotion: true));
    await tester.pumpAndSettle();
    expect(find.text('Gold'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
    expect(find.textContaining('******3210'), findsOneWidget);
    expect(find.textContaining('9876543210'), findsNothing);
    expect(find.textContaining('累计充值'), findsNothing);
    expect(find.textContaining('₹'), findsNothing);
    expect(find.textContaining('suggested'), findsNothing);
    expectNoVipWriteCtas(tester);
  });

  testWidgets('unknown VIP tier stays empty instead of inventing a rank', (
    tester,
  ) async {
    setView(tester, const Size(390, 844));
    await tester.pumpWidget(host(profile(tier: 'UNKNOWN'), reduceMotion: true));
    await tester.pumpAndSettle();
    expect(find.text('--'), findsWidgets);
    expect(find.text('UNKNOWN'), findsNothing);
    expectNoVipWriteCtas(tester);
  });

  testWidgets('VIP label fits 320 at text scale 1.3 with reduced motion', (
    tester,
  ) async {
    setView(tester, const Size(320, 568));
    await tester.pumpWidget(
      host(
        profile(tier: 'PLATINUM', status: 'SUSPENDED'),
        size: const Size(320, 568),
        textScale: 1.3,
        reduceMotion: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Platinum'), findsOneWidget);
    expect(find.text('Suspended'), findsOneWidget);
    expect(find.byType(MembershipTierBadge), findsOneWidget);
    expectNoVipWriteCtas(tester);
  });

  testWidgets('VIP badge has a screen-reader name', (tester) async {
    final handle = tester.ensureSemantics();
    try {
      await tester.pumpWidget(host(const Scaffold(body: MembershipTierBadge(tier: 'SILVER'))));
      expect(find.bySemanticsLabel('Membership tier SILVER'), findsOneWidget);
    } finally {
      handle.dispose();
    }
  });
}
