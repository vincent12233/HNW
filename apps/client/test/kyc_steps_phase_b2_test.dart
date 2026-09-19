import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:india_trading_app/models/picked_bytes_file.dart';
import 'package:india_trading_app/pages/bank_details_page.dart';
import 'package:india_trading_app/pages/kyc_upload_page.dart';
import 'package:india_trading_app/pages/selfie_camera_page.dart';
import 'package:india_trading_app/theme/app_motion.dart';
import 'package:india_trading_app/theme/app_theme.dart';
import 'package:india_trading_app/theme/auth_layout.dart';
import 'package:india_trading_app/widgets/kyc_signature_pad.dart';
import 'package:india_trading_app/widgets/onboarding_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

Uint8List _tinyPng() => Uint8List.fromList(
  base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
  ),
);

PickedBytesFile _pngFile(String name) =>
    PickedBytesFile(name: name, bytes: _tinyPng());

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  Finder stepScroll() => find.descendant(
    of: find.byKey(const ValueKey('kyc-overview-scroll')),
    matching: find.byType(Scrollable),
  );

  Future<void> pumpPage(
    WidgetTester tester, {
    required Widget home,
    Size size = const Size(390, 844),
    double textScale = 1,
    bool reduceMotion = false,
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
            disableAnimations: reduceMotion,
            accessibleNavigation: reduceMotion,
          ),
          child: child!,
        ),
        home: KeyedSubtree(key: UniqueKey(), child: home),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  void expectNoFalseClaims(WidgetTester tester, {required String reason}) {
    expect(find.textContaining('OTP'), findsNothing, reason: reason);
    expect(find.textContaining('OCR'), findsNothing, reason: reason);
    expect(find.textContaining('DigiLocker'), findsNothing, reason: reason);
    expect(find.textContaining('liveness'), findsNothing, reason: reason);
    expect(find.textContaining('Liveness'), findsNothing, reason: reason);
    expect(find.text('Verified'), findsNothing, reason: reason);
    expect(
      find.textContaining('officially verified'),
      findsNothing,
      reason: reason,
    );
    expect(
      find.textContaining('government database'),
      findsNothing,
      reason: reason,
    );
    expect(find.textContaining('活体认证通过'), findsNothing, reason: reason);
    expect(find.textContaining('真人检测成功'), findsNothing, reason: reason);
    expect(tester.takeException(), isNull, reason: reason);
  }

  void expectFooterAbove(
    WidgetTester tester, {
    required Finder content,
    required String reason,
  }) {
    final contentRect = tester.getRect(content);
    final footerRect = tester.getRect(find.byKey(const ValueKey('kyc-footer')));
    expect(
      contentRect.bottom,
      lessThanOrEqualTo(footerRect.top + 1),
      reason: '$reason content sits above footer',
    );
    expect(
      tester.getRect(find.byType(AuthSubmitButton).last).overlaps(contentRect),
      isFalse,
      reason: '$reason button does not cover content',
    );
  }

  group('documents', () {
    testWidgets('PAN and Aadhaar required rules stay unchanged', (tester) async {
      await pumpPage(
        tester,
        home: const KycUploadPage(
          debugHarness: KycUploadDebugHarness(
            step: 1,
            documentType: 'PAN',
            fullName: 'Test Customer',
          ),
        ),
      );
      expect(find.text('PAN Card Front (Required)'), findsOneWidget);
      expect(find.text('Aadhaar Back (Required)'), findsNothing);
      await tester.tap(find.text('Continue'));
      await tester.pump();
      expect(find.text('Add your PAN document'), findsOneWidget);

      await pumpPage(
        tester,
        home: const KycUploadPage(
          debugHarness: KycUploadDebugHarness(
            step: 1,
            documentType: 'AADHAAR',
            fullName: 'Test Customer',
          ),
        ),
      );
      expect(find.text('Aadhaar Front (Required)'), findsOneWidget);
      expect(find.text('Aadhaar Back (Required)'), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await tester.pump();
      expect(find.text('Add both the front and back of Aadhaar'), findsOneWidget);
      expect(find.text('Capture Selfie'), findsNothing);
      expectNoFalseClaims(tester, reason: 'document rules');
    });

    testWidgets('select preview replace and clear stay local', (tester) async {
      var pickCount = 0;
      await pumpPage(
        tester,
        home: KycUploadPage(
          debugHarness: KycUploadDebugHarness(
            step: 1,
            documentType: 'PAN',
            fullName: 'Test Customer',
            pickDocument: ({required back}) async {
              pickCount += 1;
              return _pngFile(pickCount == 1 ? 'pan-front.png' : 'pan-replaced.png');
            },
          ),
        ),
      );
      await tester.tap(find.text('Choose File'));
      await tester.pumpAndSettle();
      expect(find.text('Selected'), findsOneWidget);
      expect(find.textContaining('pan-front.png'), findsWidgets);
      expect(find.textContaining('Verified'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Replace File'),
        180,
        scrollable: stepScroll(),
      );
      await tester.tap(find.text('Replace File'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.textContaining('pan-replaced.png'),
        120,
        scrollable: stepScroll(),
      );
      expect(find.textContaining('pan-replaced.png'), findsWidgets);
      expect(find.text('Selected'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Remove File'),
        120,
        scrollable: stepScroll(),
      );
      await tester.tap(find.text('Remove File'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'This only clears the file selected on this device. It does not delete anything already submitted for review.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      expect(find.text('Selected'), findsNothing);
      expect(find.text('Choose File'), findsOneWidget);
      expectNoFalseClaims(tester, reason: 'local file actions');
      expect(pickCount, 2);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      expect(pickCount, 2, reason: 'animation ticks must not pick again');
    });

    testWidgets('unsupported and oversized files stay on the document step', (
      tester,
    ) async {
      var kind = 'gif';
      await pumpPage(
        tester,
        home: KycUploadPage(
          debugHarness: KycUploadDebugHarness(
            step: 1,
            documentType: 'PAN',
            fullName: 'Test Customer',
            pickDocument: ({required back}) async {
              if (kind == 'gif') {
                return PickedBytesFile(
                  name: 'card.gif',
                  bytes: Uint8List.fromList([1, 2, 3]),
                );
              }
              return PickedBytesFile(
                name: 'huge.jpg',
                bytes: Uint8List(15 * 1024 * 1024 + 1),
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('Choose File'));
      await tester.pumpAndSettle();
      expect(
        find.text('Choose a PDF, JPG, PNG, WebP, HEIC or HEIF file'),
        findsOneWidget,
      );
      kind = 'huge';
      await tester.scrollUntilVisible(
        find.text('Choose File'),
        180,
        scrollable: stepScroll(),
      );
      await tester.tap(find.text('Choose File'));
      await tester.pumpAndSettle();
      expect(find.text('Each KYC file must be 15 MB or smaller'), findsOneWidget);
      expect(find.text('Capture Selfie'), findsNothing);
    });
  });

  group('selfie', () {
    testWidgets('capture preview and retake use the existing file path', (
      tester,
    ) async {
      var takes = 0;
      await pumpPage(
        tester,
        home: KycUploadPage(
          debugHarness: KycUploadDebugHarness(
            step: 2,
            fullName: 'Test Customer',
            pickSelfie: ({required source}) async {
              takes += 1;
              return _pngFile(takes == 1 ? 'selfie.png' : 'selfie-retake.png');
            },
          ),
        ),
      );
      expect(find.text('Capture Selfie'), findsOneWidget);
      expect(find.text('Choose from Gallery'), findsOneWidget);
      await tester.tap(find.text('Capture Selfie'));
      await tester.pumpAndSettle();
      expect(find.text('Selfie captured'), findsOneWidget);
      expect(find.text('Waiting for manual review'), findsOneWidget);
      expect(find.text('Retake'), findsOneWidget);
      await tester.tap(find.text('Retake'));
      await tester.pumpAndSettle();
      expect(find.text('Selfie captured'), findsOneWidget);
      expectNoFalseClaims(tester, reason: 'selfie capture');
    });

    testWidgets('camera permission failure stays honest', (tester) async {
      await pumpPage(
        tester,
        home: const SelfieCameraPage(
          debugForceError:
              'Unable to open the front camera. Allow camera access in your phone settings.',
        ),
      );
      expect(find.textContaining('camera'), findsWidgets);
      expect(find.text('Retry'), findsOneWidget);
      expectNoFalseClaims(tester, reason: 'camera permission');
    });
  });

  group('signature', () {
    testWidgets('blank signature cannot continue and clear does not submit', (
      tester,
    ) async {
      await pumpPage(
        tester,
        home: const KycUploadPage(
          debugHarness: KycUploadDebugHarness(
            step: 3,
            fullName: 'Test Customer',
          ),
        ),
      );
      await tester.tap(find.text('Continue'));
      await tester.pump();
      expect(find.text('Save your signature to continue'), findsOneWidget);
      await tester.tap(find.text('Save Signature'));
      await tester.pump();
      expect(
        find.text('Please draw your signature before saving.'),
        findsOneWidget,
      );
      await tester.drag(
        find.byKey(const ValueKey('signature-canvas')),
        const Offset(120, 40),
      );
      await tester.pump();
      await tester.tap(find.text('Clear'));
      await tester.pump();
      await tester.tap(find.text('Save Signature'));
      await tester.pump();
      expect(
        find.text('Please draw your signature before saving.'),
        findsOneWidget,
      );
      expect(find.text('Signature saved'), findsNothing);
    });

    testWidgets('drawing can be saved and retaken', (tester) async {
      var saved = false;
      await pumpPage(
        tester,
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: KycSignaturePad(
              onSaved: (_) => saved = true,
              onChanged: () {},
            ),
          ),
        ),
      );
      await tester.timedDrag(
        find.byKey(const ValueKey('signature-canvas')),
        const Offset(160, 40),
        const Duration(milliseconds: 400),
      );
      await tester.pump();
      await tester.tap(find.text('Save Signature'));
      await tester.pump();
      await tester.runAsync(() async {
        final deadline = DateTime.now().add(const Duration(seconds: 2));
        while (!saved && DateTime.now().isBefore(deadline)) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
      });
      await tester.pump();
      expect(saved, isTrue);

      await pumpPage(
        tester,
        home: KycUploadPage(
          debugHarness: KycUploadDebugHarness(
            step: 3,
            fullName: 'Test Customer',
            signatureFile: _pngFile('signature.png'),
          ),
        ),
      );
      expect(find.text('Signature saved'), findsOneWidget);
      expect(find.text('Waiting for manual review'), findsOneWidget);
      await tester.tap(find.text('Retake Signature'));
      await tester.pump();
      expect(find.byKey(const ValueKey('signature-canvas')), findsOneWidget);
    });

    testWidgets('normalized coordinates stay in bounds across widths', (
      tester,
    ) async {
      await pumpPage(
        tester,
        size: const Size(320, 568),
        home: const KycUploadPage(
          debugHarness: KycUploadDebugHarness(
            step: 3,
            fullName: 'Test Customer',
          ),
        ),
      );
      final small = tester.getSize(find.byKey(const ValueKey('signature-canvas')));
      expect(small.width, lessThanOrEqualTo(320));
      await tester.timedDrag(
        find.byKey(const ValueKey('signature-canvas')),
        Offset(small.width - 24, 24),
        const Duration(milliseconds: 400),
      );
      expect(tester.takeException(), isNull);

      await pumpPage(
        tester,
        size: const Size(768, 1024),
        home: const KycUploadPage(
          debugHarness: KycUploadDebugHarness(
            step: 3,
            fullName: 'Test Customer',
          ),
        ),
      );
      final wide = tester.getSize(find.byKey(const ValueKey('signature-canvas')));
      expect(wide.width, lessThanOrEqualTo(AuthLayout.maxFormWidth + 0.5));
      await tester.timedDrag(
        find.byKey(const ValueKey('signature-canvas')),
        const Offset(180, 30),
        const Duration(milliseconds: 400),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('bank', () {
    testWidgets('payload fields stay the same without OTP or instant claims', (
      tester,
    ) async {
      late Map<String, String> payload;
      var calls = 0;
      await pumpPage(
        tester,
        home: BankDetailsPage(
          initial: const {'accountHolder': 'Test Customer'},
          onContinue: (value) {
            calls += 1;
            payload = value;
          },
        ),
      );
      expect(find.text('Account Holder Name'), findsWidgets);
      expect(find.text('Account Number'), findsWidgets);
      expect(find.text('Confirm Account Number'), findsWidgets);
      expect(find.text('IFSC Code (Optional)'), findsWidgets);
      expect(find.text('Bank Name'), findsWidgets);
      await tester.enterText(find.byType(TextFormField).at(1), '123456789012');
      await tester.enterText(find.byType(TextFormField).at(2), '123456789012');
      await tester.enterText(find.byType(TextFormField).at(3), 'HDFC0001234');
      await tester.enterText(find.byType(TextFormField).at(4), 'HDFC Bank');
      await tester.ensureVisible(find.byType(AuthSubmitButton));
      await tester.tap(find.byType(AuthSubmitButton));
      await tester.pump();
      expect(calls, 1);
      expect(payload.keys.toSet(), {
        'bankName',
        'accountHolder',
        'accountNumber',
        'ifscCode',
      });
      expect(payload['accountHolder'], 'Test Customer');
      expect(payload['accountNumber'], '123456789012');
      expect(payload['ifscCode'], 'HDFC0001234');
      expect(payload['bankName'], 'HDFC Bank');
      await tester.tap(find.text('Continue'));
      await tester.pump();
      expect(calls, 1);
      expectNoFalseClaims(tester, reason: 'bank payload');
    });

    testWidgets('confirm mismatch and IFSC rule stay local', (tester) async {
      await pumpPage(tester, home: const BankDetailsPage());
      await tester.enterText(find.byType(TextFormField).at(0), 'Test Account');
      await tester.enterText(find.byType(TextFormField).at(1), '123456789');
      await tester.enterText(find.byType(TextFormField).at(2), '111111111');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Account numbers do not match'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).at(2), '123456789');
      await tester.enterText(find.byType(TextFormField).at(3), 'BAD');
      await tester.enterText(find.byType(TextFormField).at(4), 'HDFC Bank');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a valid IFSC code'), findsOneWidget);
      expectNoFalseClaims(tester, reason: 'bank validation');
    });
  });

  group('responsive', () {
    const sizes = <Size>[
      Size(320, 568),
      Size(390, 844),
      Size(414, 896),
      Size(768, 1024),
    ];

    testWidgets('document selfie signature and bank fit listed phones', (
      tester,
    ) async {
      for (final size in sizes) {
        await pumpPage(
          tester,
          size: size,
          home: KycUploadPage(
            debugHarness: KycUploadDebugHarness(
              step: 1,
              documentType: 'AADHAAR',
              fullName: 'Test Customer',
              selectedFile: _pngFile('front.png'),
              selectedBackFile: _pngFile('back.png'),
            ),
          ),
        );
        expect(find.text('Aadhaar Front (Required)'), findsOneWidget);
        expect(find.text('Continue'), findsOneWidget);
        final lastAction = find.descendant(
          of: find.byKey(const ValueKey('kyc-document-back')),
          matching: find.text('Remove File'),
        );
        await tester.scrollUntilVisible(
          lastAction,
          180,
          scrollable: stepScroll(),
        );
        expectFooterAbove(
          tester,
          content: lastAction,
          reason: 'documents $size',
        );
        expect(tester.takeException(), isNull, reason: 'documents $size');

        await pumpPage(
          tester,
          size: size,
          home: const KycUploadPage(
            debugHarness: KycUploadDebugHarness(
              step: 2,
              fullName: 'Test Customer',
            ),
          ),
        );
        expect(find.text('Capture Selfie'), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'selfie $size');

        await pumpPage(
          tester,
          size: size,
          home: const KycUploadPage(
            debugHarness: KycUploadDebugHarness(
              step: 3,
              fullName: 'Test Customer',
            ),
          ),
        );
        expect(find.byKey(const ValueKey('signature-canvas')), findsOneWidget);
        expect(
          tester.getSize(find.byKey(const ValueKey('signature-canvas'))).width,
          lessThanOrEqualTo(size.width),
        );
        expect(tester.takeException(), isNull, reason: 'signature $size');

        await pumpPage(
          tester,
          size: size,
          home: const BankDetailsPage(
            initial: {'accountHolder': 'Test Customer'},
            onContinue: _unusedContinue,
          ),
        );
        expect(find.text('Continue'), findsOneWidget);
        expect(
          tester.getSize(find.byType(AuthSubmitButton)).height,
          AuthLayout.buttonHeight,
        );
        expect(tester.takeException(), isNull, reason: 'bank $size');
      }
    });

    testWidgets('1.3 text scale keeps footer and 48px button', (tester) async {
      await pumpPage(
        tester,
        size: const Size(320, 568),
        textScale: 1.3,
        home: const KycUploadPage(
          debugHarness: KycUploadDebugHarness(
            step: 1,
            documentType: 'PAN',
            fullName: 'Test Customer',
          ),
        ),
      );
      expect(find.text('Continue'), findsOneWidget);
      expect(
        tester.getSize(find.byType(AuthSubmitButton).last).height,
        AuthLayout.buttonHeight,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('motion and icons', () {
    testWidgets('reduced motion has no slide or scale and keeps copy', (
      tester,
    ) async {
      await pumpPage(
        tester,
        reduceMotion: true,
        home: const KycUploadPage(
          debugHarness: KycUploadDebugHarness(
            step: 1,
            documentType: 'PAN',
            fullName: 'Test Customer',
          ),
        ),
      );
      expect(find.text('PAN Card Front (Required)'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(KycFadeIn),
          matching: find.byType(SlideTransition),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(KycFadeIn),
          matching: find.byType(ScaleTransition),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(KycStatusSwitch),
          matching: find.byType(ScaleTransition),
        ),
        findsNothing,
      );
      expect(find.text('Selected'), findsNothing);
      expectNoFalseClaims(tester, reason: 'reduced motion document');

      await pumpPage(
        tester,
        reduceMotion: true,
        home: KycUploadPage(
          debugHarness: KycUploadDebugHarness(
            step: 2,
            fullName: 'Test Customer',
            selfieFile: _pngFile('selfie.png'),
          ),
        ),
      );
      expect(find.text('Selfie captured'), findsOneWidget);
      expect(find.text('Waiting for manual review'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(KycStatusSwitch),
          matching: find.byType(ScaleTransition),
        ),
        findsNothing,
      );
      expectNoFalseClaims(tester, reason: 'reduced motion selfie');
    });

    testWidgets('busy continue keeps 48px height', (tester) async {
      await pumpPage(
        tester,
        home: BankDetailsPage(
          initial: const {
            'accountHolder': 'Test Customer',
            'accountNumber': '123456789012',
            'ifscCode': 'HDFC0001234',
            'bankName': 'HDFC Bank',
          },
          onContinue: (_) {},
        ),
      );
      await tester.enterText(find.byType(TextFormField).at(2), '123456789012');
      final idle = tester.getSize(find.byType(AuthSubmitButton));
      await tester.ensureVisible(find.byType(AuthSubmitButton));
      await tester.tap(find.byType(AuthSubmitButton));
      await tester.pump();
      expect(tester.getSize(find.byType(AuthSubmitButton)).height, idle.height);
      expect(tester.getSize(find.byType(AuthSubmitButton)).height, 48);
    });

    testWidgets('icon buttons expose labels and 44px targets', (tester) async {
      await pumpPage(
        tester,
        home: const BankDetailsPage(initial: {'accountHolder': 'Test Customer'}),
      );
      final visibility = find.byTooltip('Show account number');
      expect(visibility, findsWidgets);
      final size = tester.getSize(visibility.first);
      expect(size.width, greaterThanOrEqualTo(44));
      expect(size.height, greaterThanOrEqualTo(44));

      await pumpPage(
        tester,
        home: const KycUploadPage(
          debugHarness: KycUploadDebugHarness(
            step: 3,
            fullName: 'Test Customer',
          ),
        ),
      );
      expect(find.byTooltip('Clear'), findsOneWidget);
      final clear = tester.getSize(find.byTooltip('Clear'));
      expect(clear.width, greaterThanOrEqualTo(44));
      expect(clear.height, greaterThanOrEqualTo(44));
      expect(find.byIcon(Icons.upload_file), findsNothing);
    });

    testWidgets('1.3 text scale keeps status icons visible', (tester) async {
      await pumpPage(
        tester,
        textScale: 1.3,
        size: const Size(320, 568),
        home: KycUploadPage(
          debugHarness: KycUploadDebugHarness(
            step: 1,
            documentType: 'PAN',
            fullName: 'Test Customer',
            selectedFile: _pngFile('pan-front.png'),
          ),
        ),
      );
      expect(find.byIcon(Icons.swap_horiz), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
      expect(find.text('Selected'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await pumpPage(
        tester,
        textScale: 1.3,
        size: const Size(320, 568),
        home: KycUploadPage(
          debugHarness: KycUploadDebugHarness(
            step: 3,
            fullName: 'Test Customer',
            signatureFile: _pngFile('signature.png'),
          ),
        ),
      );
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.text('Signature saved'), findsOneWidget);
      expect(find.textContaining('Verified'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('320 width has no overflow after file preview fade', (
      tester,
    ) async {
      await pumpPage(
        tester,
        size: const Size(320, 568),
        home: KycUploadPage(
          debugHarness: KycUploadDebugHarness(
            step: 1,
            documentType: 'PAN',
            fullName: 'Test Customer',
            pickDocument: ({required back}) async => _pngFile('pan-front.png'),
          ),
        ),
      );
      await tester.scrollUntilVisible(
        find.text('Choose File'),
        180,
        scrollable: stepScroll(),
      );
      await tester.tap(find.text('Choose File'));
      await tester.pumpAndSettle();
      expect(find.textContaining('pan-front.png'), findsWidgets);
      expect(find.text('Selected'), findsOneWidget);
      expect(find.textContaining('%'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}

void _unusedContinue(Map<String, String> value) {}
