import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:india_trading_app/theme/app_theme.dart';
import 'package:india_trading_app/widgets/app_status_scene.dart';

void main() {
  testWidgets('support unavailable visual baseline', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: const Scaffold(
          body: RepaintBoundary(
            key: ValueKey('golden'),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: AppStatusScene(
                icon: Icons.support_agent_rounded,
                title: 'Customer support is unavailable',
                message: 'We could not open the secure support service.',
                status: 'Unavailable',
                nextStep: 'Please try again shortly.',
              ),
            ),
          ),
        ),
      ),
    );
    await expectLater(
      find.byKey(const ValueKey('golden')),
      matchesGoldenFile('support_unavailable_390x844.png'),
    );
  });
}
