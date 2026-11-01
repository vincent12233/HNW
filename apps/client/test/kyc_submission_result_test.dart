import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:india_trading_app/l10n/app_language.dart';
import 'package:india_trading_app/theme/app_theme.dart';
import 'package:india_trading_app/widgets/kyc_submission_result.dart';

void main() {
  Future<void> pumpResult(
    WidgetTester tester, {
    required Size size,
    double textScale = 1,
    String language = 'en',
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    AppLanguage.instance.code = language;
    addTearDown(() => AppLanguage.instance.code = 'en');
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(body: KycSubmissionResult(onDone: () {})),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('submitted state explains the identity review lifecycle', (
    tester,
  ) async {
    await pumpResult(tester, size: const Size(390, 844));

    expect(find.text('Documents received'), findsOneWidget);
    expect(find.text('Submitted'), findsWidgets);
    expect(find.text('Identity review'), findsOneWidget);
    expect(find.text('Result'), findsOneWidget);
    expect(find.textContaining('estimated'), findsNothing);
    expect(find.byIcon(Icons.hourglass_top_rounded), findsNothing);
    expect(find.text('Done'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('result remains usable on small and enlarged Hindi layouts', (
    tester,
  ) async {
    await pumpResult(
      tester,
      size: const Size(320, 568),
      textScale: 1.3,
      language: 'hi',
    );

    expect(find.text('दस्तावेज़ प्राप्त हुए'), findsOneWidget);
    expect(find.text('हो गया'), findsOneWidget);
    expect(find.byType(Scrollable), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
