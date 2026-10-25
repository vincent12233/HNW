import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:india_trading_app/pages/login_page.dart';
import 'package:india_trading_app/pages/register_page.dart';
import 'package:india_trading_app/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final entry in <String, Widget>{
    'login': LoginPage(onSignedIn: (_) {}),
    'register': const RegisterPage(),
  }.entries) {
    testWidgets('${entry.key} protected visual baseline', (tester) async {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('golden'),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            home: entry.value,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byKey(const ValueKey('golden')),
        matchesGoldenFile('${entry.key}_390x844.png'),
      );
    });
  }
}
