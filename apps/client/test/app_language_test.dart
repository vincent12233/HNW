import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:india_trading_app/l10n/app_language.dart';
import 'package:india_trading_app/pages/account_content_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });
  test('English is default and Hindi survives reload', () async {
    await AppLanguage.instance.load();
    expect(tr('Portfolio'), 'Portfolio');
    await AppLanguage.instance.select('hi');
    await AppLanguage.instance.load();
    expect(tr('Portfolio'), 'पोर्टफोलियो');
    await AppLanguage.instance.select('en');
  });
  testWidgets(
    'Hindi renders learning articles without overflow on a narrow screen',
    (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await AppLanguage.instance.select('hi');
      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('hi'),
          supportedLocales: [Locale('en'), Locale('hi')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: LearningCenterPage(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('शिक्षण केंद्र'), findsOneWidget);
      await tester.tap(find.byType(ListTile).first);
      await tester.pumpAndSettle();
      expect(find.byType(SelectableText), findsOneWidget);
      expect(tester.takeException(), isNull);
      await AppLanguage.instance.select('en');
    },
  );
}
