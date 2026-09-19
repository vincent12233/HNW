import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:india_trading_app/pages/kyc_upload_page.dart';
import 'package:india_trading_app/theme/app_theme.dart';
import 'package:india_trading_app/theme/auth_layout.dart';
import 'package:india_trading_app/widgets/onboarding_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

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
  ];

  const stepTitles = [
    'Personal Details',
    'Upload documents',
    'Selfie',
    'Signature',
    'Bank Account Details',
    'Review & submit',
  ];

  Finder overviewScroll() => find.descendant(
    of: find.byKey(const ValueKey('kyc-overview-scroll')),
    matching: find.byType(Scrollable),
  );

  Future<void> pumpOverview(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    double textScale = 1,
    Widget? home,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
          ),
          child: child!,
        ),
        home: home ?? const KycUploadPage(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  Future<void> revealLastStep(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('kyc-step-5')),
      180,
      scrollable: overviewScroll(),
    );
    await tester.pump();
  }

  void expectLastStepAboveFooter(WidgetTester tester, {required Object reason}) {
    final stepRect = tester.getRect(find.byKey(const ValueKey('kyc-step-5')));
    final footerRect = tester.getRect(find.byKey(const ValueKey('kyc-footer')));
    final scrollRect = tester.getRect(
      find.byKey(const ValueKey('kyc-overview-scroll')),
    );
    expect(
      scrollRect.bottom,
      closeTo(footerRect.top, 1.5),
      reason: '$reason scroll sits above footer',
    );
    expect(
      stepRect.bottom,
      lessThanOrEqualTo(footerRect.top + 1),
      reason: '$reason last step is above footer',
    );
    expect(
      stepRect.top,
      greaterThanOrEqualTo(scrollRect.top - 1),
      reason: '$reason last step is in the scroll viewport',
    );
    expect(
      tester.getRect(find.byType(AuthSubmitButton)).overlaps(stepRect),
      isFalse,
      reason: '$reason button does not cover last step',
    );
  }

  testWidgets('overview lists the six KYC steps in order without OTP', (
    tester,
  ) async {
    await pumpOverview(tester);
    expect(find.text('HNW'), findsOneWidget);
    expect(find.text('KYC Verification'), findsWidgets);
    var last = -1.0;
    for (final title in stepTitles) {
      final finder = find.text(title);
      expect(finder, findsWidgets, reason: title);
      final offset = tester.getTopLeft(finder.first).dy;
      expect(offset, greaterThan(last), reason: '$title order');
      last = offset;
    }
    expect(find.textContaining('OTP'), findsNothing);
    expect(find.textContaining('Aadhaar OTP'), findsNothing);
    expect(find.textContaining('verification code'), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Continue Verification'), findsOneWidget);
    expect(find.text('Not started'), findsWidgets);
    expect(find.text('In progress'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Continue Verification still opens personal details first', (
    tester,
  ) async {
    await pumpOverview(tester, size: const Size(390, 2000));
    await tester.ensureVisible(find.text('Continue Verification'));
    await tester.tap(find.text('Continue Verification'));
    await tester.pumpAndSettle();
    expect(find.text('Personal Details'), findsWidgets);
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Capture Selfie'), findsNothing);
    expect(find.textContaining('OTP'), findsNothing);
    expect(find.widgetWithText(TextField, 'OTP'), findsNothing);
  });

  testWidgets('PENDING uses status API and does not add a new action', (
    tester,
  ) async {
    await http.runWithClient(() async {
      await pumpOverview(
        tester,
        home: const KycUploadPage(accessToken: 'kyc-token'),
      );
      expect(find.text('Verification in Progress'), findsWidgets);
      expect(
        find.text('Your documents are waiting for business review.'),
        findsOneWidget,
      );
      expect(find.text('Back to Login'), findsOneWidget);
      expect(find.text('Continue Verification'), findsNothing);
      expect(find.text('Submit KYC for Review'), findsNothing);
      expect(find.text('Completed'), findsWidgets);
      expect(find.textContaining('OTP'), findsNothing);
      expect(find.byType(TextField), findsNothing);
    }, () {
      return MockClient((request) async {
        expect(request.url.path, '/kyc/status');
        return http.Response(
          jsonEncode({'status': 'PENDING', 'reviewNote': null}),
          200,
        );
      });
    });
  });

  testWidgets('APPROVED only shows the current review result', (tester) async {
    await http.runWithClient(() async {
      await pumpOverview(
        tester,
        home: const KycUploadPage(accessToken: 'kyc-token'),
      );
      expect(find.text('Verification Complete'), findsOneWidget);
      expect(find.text('Your account has been verified.'), findsOneWidget);
      expect(find.text('Back to Login'), findsOneWidget);
      expect(find.text('Submit KYC for Review'), findsNothing);
      expect(find.text('Continue Verification'), findsNothing);
      expect(find.text('ACTIVE'), findsNothing);
      expect(find.byType(TextField), findsNothing);
    }, () {
      return MockClient(
        (_) async => http.Response(jsonEncode({'status': 'APPROVED'}), 200),
      );
    });
  });

  testWidgets('REJECTED keeps the existing resubmit path and review note', (
    tester,
  ) async {
    await http.runWithClient(() async {
      await pumpOverview(
        tester,
        home: const KycUploadPage(accessToken: 'kyc-token'),
      );
      expect(find.text('Needs resubmission'), findsOneWidget);
      expect(find.text('Blurry PAN'), findsOneWidget);
      expect(find.text('Continue Verification'), findsOneWidget);
      expect(find.text('Back to Login'), findsNothing);
      await tester.ensureVisible(find.text('Continue Verification'));
      await tester.tap(find.text('Continue Verification'));
      await tester.pumpAndSettle();
      expect(find.text('Save'), findsOneWidget);
      expect(find.textContaining('OTP'), findsNothing);
    }, () {
      return MockClient(
        (_) async => http.Response(
          jsonEncode({'status': 'REJECTED', 'reviewNote': 'Blurry PAN'}),
          200,
        ),
      );
    });
  });

  testWidgets('overview fits listed phones without overflow', (tester) async {
    for (final size in sizes) {
      await pumpOverview(tester, size: size);
      expect(find.text('HNW'), findsOneWidget, reason: '$size logo');
      expect(
        find.text('Continue Verification'),
        findsOneWidget,
        reason: '$size continue',
      );
      expect(find.text('Personal Details'), findsWidgets, reason: '$size step');
      expect(tester.takeException(), isNull, reason: '$size overflow');
    }
  });

  testWidgets('320x568 can scroll the last step fully above the footer', (
    tester,
  ) async {
    await pumpOverview(tester, size: const Size(320, 568));
    await revealLastStep(tester);
    expect(find.text('Review & submit'), findsWidgets);
    expect(find.text('Continue Verification'), findsOneWidget);
    expectLastStepAboveFooter(tester, reason: '320x568');
    expect(tester.takeException(), isNull);
  });

  testWidgets('390x844 footer does not cover verification steps', (
    tester,
  ) async {
    await pumpOverview(tester, size: const Size(390, 844));
    final footerRect = tester.getRect(find.byKey(const ValueKey('kyc-footer')));
    final scrollRect = tester.getRect(
      find.byKey(const ValueKey('kyc-overview-scroll')),
    );
    expect(scrollRect.bottom, closeTo(footerRect.top, 1.5));
    expect(find.text('Continue Verification'), findsOneWidget);
    await revealLastStep(tester);
    expectLastStepAboveFooter(tester, reason: '390x844');
    expect(tester.takeException(), isNull);
  });

  testWidgets('414x896 keeps a stable in-flow footer', (tester) async {
    await pumpOverview(tester, size: const Size(414, 896));
    final firstFooter = tester.getRect(find.byKey(const ValueKey('kyc-footer')));
    final firstButton = tester.getSize(find.byType(AuthSubmitButton));
    await revealLastStep(tester);
    final afterFooter = tester.getRect(find.byKey(const ValueKey('kyc-footer')));
    expect(afterFooter.height, closeTo(firstFooter.height, 1));
    expect(
      tester.getSize(find.byType(AuthSubmitButton)).height,
      firstButton.height,
    );
    expectLastStepAboveFooter(tester, reason: '414x896');
    expect(tester.takeException(), isNull);
  });

  testWidgets('768x1024 content stays constrained instead of stretching', (
    tester,
  ) async {
    await pumpOverview(tester, size: const Size(768, 1024));
    expect(
      tester.getSize(find.byKey(const ValueKey('kyc-overview-scroll'))).width,
      lessThanOrEqualTo(AuthLayout.maxFormWidth + 0.5),
    );
    expect(
      tester.getSize(find.byType(AuthSubmitButton)).width,
      lessThanOrEqualTo(AuthLayout.maxFormWidth + 0.5),
    );
    await revealLastStep(tester);
    expectLastStepAboveFooter(tester, reason: '768x1024');
    expect(tester.takeException(), isNull);
  });

  testWidgets('overview stays readable at 1.3 text scale', (tester) async {
    for (final scale in const [1.0, 1.15, 1.3]) {
      await pumpOverview(tester, size: const Size(320, 568), textScale: scale);
      expect(
        find.text('KYC Verification'),
        findsWidgets,
        reason: 'scale $scale',
      );
      expect(find.text('Continue Verification'), findsOneWidget);
      expect(find.text('Selfie'), findsWidgets);
      await revealLastStep(tester);
      expectLastStepAboveFooter(tester, reason: 'scale $scale');
      expect(
        tester.getSize(find.byType(AuthSubmitButton)).height,
        AuthLayout.buttonHeight,
      );
      expect(tester.takeException(), isNull, reason: 'scale $scale overflow');
    }
  });

  testWidgets('loading button keeps a stable height', (tester) async {
    await pumpOverview(tester);
    final idle = tester.getSize(find.byType(AuthSubmitButton));
    expect(idle.height, AuthLayout.buttonHeight);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: AuthSubmitButton(
            label: 'Continue Verification',
            busy: true,
            onPressed: null,
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(AuthSubmitButton)).height, idle.height);
    expect(tester.getSize(find.byType(AuthSubmitButton)).height, 48);
  });

  testWidgets('write overview screenshots for visual review', (tester) async {
    const targets = <(Size, String)>[
      (Size(320, 568), 'kyc-320x568.png'),
      (Size(390, 844), 'kyc-390x844.png'),
      (Size(414, 896), 'kyc-414x896.png'),
      (Size(768, 1024), 'kyc-768x1024.png'),
    ];
    final out = Directory('/tmp/hnw-phase-b1-visual');
    out.createSync(recursive: true);
    for (final (size, name) in targets) {
      await pumpOverview(tester, size: size);
      await revealLastStep(tester);
      expectLastStepAboveFooter(tester, reason: name);
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byType(RepaintBoundary).first,
      );
      final bytes = await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        return data!.buffer.asUint8List();
      });
      expect(bytes, isNotNull, reason: name);
      expect(bytes!.length, greaterThan(1000), reason: '$name empty');
      final decoded = await tester.runAsync(() async {
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        return Size(
          frame.image.width.toDouble(),
          frame.image.height.toDouble(),
        );
      });
      expect(decoded, size, reason: '$name dimensions');
      File('${out.path}/$name').writeAsBytesSync(bytes);
    }
  });
}
