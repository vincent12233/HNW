import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:india_trading_app/pages/market_page.dart';
import 'package:india_trading_app/pages/login_page.dart';
import 'package:india_trading_app/pages/register_page.dart';
import 'package:india_trading_app/pages/kyc_upload_page.dart';
import 'package:india_trading_app/pages/bank_details_page.dart';
import 'package:india_trading_app/widgets/kyc_signature_pad.dart';
import 'package:india_trading_app/theme/app_theme.dart';
import 'package:india_trading_app/pages/account_security_page.dart';
import 'package:india_trading_app/pages/account_content_page.dart';
import 'package:india_trading_app/services/insight_articles_service.dart';
import 'package:india_trading_app/pages/language_page.dart';
import 'package:india_trading_app/pages/appearance_page.dart';
import 'package:india_trading_app/pages/legal_page.dart';
import 'package:india_trading_app/pages/notifications_page.dart';

// Opt-in renders of the production widgets, with no customer data or mock API.
// flutter test test/ui_capture_test.dart --update-goldens
//   --dart-define=UI_CAPTURE_DIR=<absolute output directory>
void main() {
  const output = String.fromEnvironment('UI_CAPTURE_DIR');
  final pages = <String, Widget>{
    'password': const AccountSecurityPage(),
    'wealth_insights': const WealthInsightsPage(),
    'article': const WealthInsightArticlePage(
      article: InsightArticle(
        id: 'preview',
        slug: 'preview',
        locale: 'en',
        title: 'Account and KYC',
        body: 'Review account and identity information carefully.',
      ),
    ),
    'language': const LanguagePage(),
    'appearance': const AppearancePage(),
    'privacy': const LegalPage(title: 'Privacy'),
    'risk': const LegalPage(title: 'Risk Disclosure'),
    'notifications': const NotificationsPage(),
    'login': LoginPage(onSignedIn: (_) {}),
    'register': const RegisterPage(),
    'kyc': const KycUploadPage(),
    'bank': const BankDetailsPage(),
    'home': const MarketHomePage(),
    'markets': const MarketHomePage(),
    'trade': const MarketHomePage(),
    'portfolio': const MarketHomePage(),
    'profile': const MarketHomePage(),
    'signature': Scaffold(
      appBar: AppBar(title: const Text('Signature')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: KycSignaturePad(onSaved: (_) {}, onChanged: () {}),
      ),
    ),
  };
  for (final entry in pages.entries) {
    testWidgets('render ${entry.key} at mobile size', (tester) async {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final font = File('C:/Windows/Fonts/arial.ttf');
      if (font.existsSync()) {
        for (final family in ['Roboto', 'Ahem']) {
          final loader = FontLoader(family)
            ..addFont(
              Future.value(ByteData.sublistView(font.readAsBytesSync())),
            );
          await loader.load();
        }
      }
      final icons = File(
        'build/unit_test_assets/fonts/MaterialIcons-Regular.otf',
      );
      if (icons.existsSync()) {
        await (FontLoader('MaterialIcons')..addFont(
              Future.value(ByteData.sublistView(icons.readAsBytesSync())),
            ))
            .load();
      }
      await tester.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('capture'),
          child: MaterialApp(
            theme: AppTheme.light(),
            debugShowCheckedModeBanner: false,
            home: entry.value,
          ),
        ),
      );
      if (entry.value is MarketHomePage) {
        for (var i = 0; i < 12; i++) {
          await tester.pump(const Duration(seconds: 10));
        }
        final index = [
          'home',
          'markets',
          'trade',
          'portfolio',
          'profile',
        ].indexOf(entry.key);
        if (index > 0) {
          await tester.tap(find.byType(NavigationDestination).at(index));
          for (var i = 0; i < 4; i++) {
            await tester.pump(const Duration(seconds: 10));
          }
        }
      } else {
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(const ValueKey('capture')),
        matchesGoldenFile(Uri.file('$output/${entry.key}.png')),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 30));
    }, skip: output.isEmpty);
  }
}
