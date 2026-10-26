import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:india_trading_app/theme/app_theme.dart';
import 'package:india_trading_app/widgets/app_status_scene.dart';

void main() {
  testWidgets('market stale-state visual baseline', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const RepaintBoundary(key: ValueKey('golden'), child: _GoldenHost()),
    );
    await expectLater(
      find.byKey(const ValueKey('golden')),
      matchesGoldenFile('market_stale_390x844.png'),
    );
  });
}

class _GoldenHost extends StatelessWidget {
  const _GoldenHost();
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light(),
    home: const Scaffold(
      body: Padding(
        padding: EdgeInsets.all(16),
        child: AppStatusScene(
          icon: Icons.cloud_off_rounded,
          title: 'Market data is delayed',
          message:
              'Last-known prices remain visible while the feed reconnects.',
          status: 'Stale',
          freshness: 'Updated 10:30 IST',
          nextStep: 'Review the timestamp before making a decision.',
        ),
      ),
    ),
  );
}
