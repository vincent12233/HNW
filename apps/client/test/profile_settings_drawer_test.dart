import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:india_trading_app/pages/account_security_page.dart';
import 'package:india_trading_app/pages/market_page.dart';
import 'package:india_trading_app/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final width in <double>[320, 390, 900]) {
    testWidgets('profile settings opens from the right at $width', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.light(), home: const MarketHomePage()),
      );
      await tester.pump(const Duration(seconds: 5));
      expect(
        find.byKey(const ValueKey('profile-settings-button')),
        findsNothing,
      );
      for (final index in <int>[1, 2, 3]) {
        await tester.tap(find.byType(NavigationDestination).at(index));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('profile-settings-button')),
          findsNothing,
        );
      }
      await tester.tap(find.byType(NavigationDestination).last);
      await tester.pumpAndSettle();

      expect(find.text('Account Overview'), findsOneWidget);
      expect(find.text('Change Login Password'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('profile-settings-button')));
      await tester.pumpAndSettle();
      expect(
        tester
            .state<ScaffoldState>(find.byType(Scaffold).first)
            .isEndDrawerOpen,
        isTrue,
      );

      final drawer = find.byKey(const ValueKey('profile-settings-drawer'));
      expect(drawer, findsOneWidget);
      expect(
        tester.getSize(drawer).width,
        closeTo(width >= 600 ? 450 : width * 0.86, 1),
      );
      expect(find.text('Change Login Password'), findsOneWidget);
      expect(find.text('Alert Preferences'), findsOneWidget);
      expect(tester.takeException(), isNull);

      if (width == 390) {
        await tester.tap(find.text('Change Login Password'));
        await tester.pumpAndSettle();
        expect(find.byType(AccountSecurityPage), findsOneWidget);
        expect(tester.takeException(), isNull);
        return;
      }

      await tester.tap(find.byKey(const ValueKey('close-profile-settings')));
      await tester.pumpAndSettle();
      expect(find.text('Change Login Password'), findsNothing);
      expect(find.text('Account Overview'), findsOneWidget);
    });
  }
}
