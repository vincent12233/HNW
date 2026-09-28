import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:india_trading_app/l10n/app_language.dart';
import 'package:india_trading_app/pages/account_content_page.dart';
import 'package:india_trading_app/services/insight_articles_service.dart';

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
  test(
    'regional language selection survives reload and translates core UI',
    () async {
      for (final entry in const {
        'ta': 'முகப்பு',
        'te': 'హోమ్',
        'kn': 'ಮುಖಪುಟ',
        'gu': 'હોમ',
        'ml': 'ഹോം',
      }.entries) {
        await AppLanguage.instance.select(entry.key);
        await AppLanguage.instance.load();
        expect(AppLanguage.instance.code, entry.key);
        expect(tr('Home'), entry.value);
        expect(tr('Terms & Conditions'), 'Terms & Conditions');
      }
      await AppLanguage.instance.select('en');
    },
  );

  test('Hindi translates profile, order and PIN field guidance', () async {
    await AppLanguage.instance.select('hi');
    expect(tr('Withdrawal Amount'), 'निकासी राशि');
    expect(tr('Search symbol or order ID'), 'सिंबल या ऑर्डर आईडी खोजें');
    expect(tr('4-digit transaction PIN'), '4 अंकों का लेन-देन पिन');
    expect(
      tr('Required. 7 to 20 characters.'),
      'आवश्यक। 7 से 20 अक्षर दर्ज करें।',
    );
    expect(tr('logo'), 'लोगो');
    await AppLanguage.instance.select('en');
  });
  test(
    'loading a different saved locale clears stale CMS copy and notifies',
    () async {
      await AppLanguage.instance.select('en');
      AppLanguage.instance.replaceRemoteCopy({'Retry': 'Old English CMS copy'});
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString('app_language', 'hi');
      var notifications = 0;
      void listener() => notifications++;
      AppLanguage.instance.addListener(listener);
      try {
        await AppLanguage.instance.load();
        expect(notifications, 1);
        expect(tr('Retry'), 'फिर प्रयास करें');
        await AppLanguage.instance.load();
        expect(notifications, 1);
      } finally {
        AppLanguage.instance.removeListener(listener);
        await AppLanguage.instance.select('en');
      }
    },
  );

  testWidgets('AppText localizes the accessibility label', (tester) async {
    await AppLanguage.instance.select('hi');
    addTearDown(() => AppLanguage.instance.select('en'));
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('hi'),
        supportedLocales: [Locale('en'), Locale('hi')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Scaffold(body: AppText('Retry', semanticsLabel: 'Retry')),
      ),
    );
    final rendered = tester.widget<Text>(find.byType(Text).first);
    expect(rendered.data, 'फिर प्रयास करें');
    expect(rendered.semanticsLabel, 'फिर प्रयास करें');
  });
  test('regional locales cover critical controls without English fallback', () {
    expect(missingCoreTranslations(), isEmpty);
  });
  test('language catalogue exposes seven supported Indian app locales', () {
    expect(appLanguageOptions.map((option) => option.code), [
      'en',
      'hi',
      'ta',
      'te',
      'kn',
      'gu',
      'ml',
    ]);
    expect(appLanguageName('te'), 'తెలుగు');
    expect(appLanguageName('unknown'), 'English');
  });
  test('remote UI copy overrides local copy for the active locale', () async {
    await AppLanguage.instance.select('en');
    AppLanguage.instance.replaceRemoteCopy({'Retry': 'Try this again'});
    expect(tr('Retry'), 'Try this again');
    AppLanguage.instance.replaceRemoteCopy(const {});
    expect(tr('Retry'), 'Retry');
  });
  test('switching locale clears overrides from the previous locale', () async {
    await AppLanguage.instance.select('en');
    AppLanguage.instance.replaceRemoteCopy({'Retry': 'English override'});
    await AppLanguage.instance.select('hi');
    expect(tr('Retry'), 'फिर प्रयास करें');
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
          home: WealthInsightArticlePage(
            article: InsightArticle(
              id: 'hindi-preview',
              slug: 'hindi-preview',
              locale: 'hi',
              title: 'खाता और केवाईसी',
              body: 'अपनी पहचान और खाते की जानकारी ध्यान से जाँचें।',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('खाता और केवाईसी'), findsOneWidget);
      expect(find.byType(SelectableText), findsOneWidget);
      expect(tester.takeException(), isNull);
      await AppLanguage.instance.select('en');
    },
  );
}
