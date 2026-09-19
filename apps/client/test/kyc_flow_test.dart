import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:india_trading_app/pages/kyc_upload_page.dart';
import 'package:india_trading_app/pages/bank_details_page.dart';
import 'package:india_trading_app/widgets/kyc_signature_pad.dart';
import 'package:india_trading_app/theme/app_theme.dart';

void main() {
  testWidgets('KYC cannot advance without the selected identity documents', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light(), home: const KycUploadPage()),
    );
    await tester.tap(find.text('Aadhaar Card'));
    await tester.ensureVisible(find.text('Continue Verification'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue Verification'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Test Customer');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue Verification'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Aadhaar Front (Required)'),
      -250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Aadhaar Front (Required)'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Aadhaar Back (Required)'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Aadhaar Back (Required)'), findsOneWidget);
    await tester.ensureVisible(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Add both the front and back of Aadhaar'), findsOneWidget);
    expect(find.text('Capture Selfie'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('blank signature cannot be saved and clear resets the drawing', (
    tester,
  ) async {
    var saved = false;
    var changes = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KycSignaturePad(
            onSaved: (_) => saved = true,
            onChanged: () => changes++,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Save Signature'));
    await tester.pump();
    expect(saved, isFalse);
    expect(
      find.text('Please draw your signature before saving.'),
      findsOneWidget,
    );
    await tester.drag(
      find.byKey(const ValueKey('signature-canvas')),
      const Offset(100, 30),
    );
    await tester.pump();
    expect(changes, greaterThan(0));
    await tester.tap(find.text('Clear'));
    await tester.tap(find.text('Save Signature'));
    await tester.pump();
    expect(saved, isFalse);
  });

  testWidgets('bank confirmation mismatch is rejected before any API call', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light(), home: const BankDetailsPage()),
    );
    await tester.enterText(find.byType(TextFormField).at(0), 'Test Account');
    await tester.enterText(find.byType(TextFormField).at(1), '123456789');
    await tester.enterText(find.byType(TextFormField).at(2), '987654321');
    await tester.ensureVisible(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Account numbers do not match'),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Account numbers do not match'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
