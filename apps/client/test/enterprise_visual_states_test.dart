import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:india_trading_app/theme/app_theme.dart';
import 'package:india_trading_app/widgets/app_status_scene.dart';

void main() {
  const output = String.fromEnvironment('UI_CAPTURE_DIR');
  const sizes = <String, Size>{
    'narrow-320': Size(320, 720),
    'phone-390': Size(390, 844),
    'tablet-768': Size(768, 1024),
  };
  final states = <String, Widget>{
    'loading': const AppStatusScene(
      icon: Icons.sync_rounded,
      title: 'Loading your account',
      message: 'Confirmed information will appear when the request completes.',
      status: 'In progress',
      freshness: 'Checking now',
      nextStep: 'Keep this screen open or return later.',
    ),
    'empty': const AppStatusScene(
      icon: Icons.inbox_outlined,
      title: 'Nothing here yet',
      message: 'New confirmed records will appear here.',
      status: 'No records',
      freshness: 'Up to date',
      nextStep: 'No action is required.',
    ),
    'offline-error': AppStatusScene(
      icon: Icons.cloud_off_rounded,
      title: 'Unable to refresh',
      message: 'Your last confirmed information has not been changed.',
      status: 'Connection unavailable',
      freshness: 'Last update retained',
      nextStep: 'Check your connection and retry.',
      primaryAction: AppStatusAction(label: 'Retry', onPressed: () {}),
    ),
    'kyc-pending': const AppStatusScene(
      icon: Icons.fact_check_outlined,
      title: 'Documents received',
      message: 'Your KYC documents are waiting for manual review.',
      status: 'Submitted',
      freshness: 'Updated just now',
      nextStep: 'The review result will appear here.',
    ),
  };

  for (final state in states.entries) {
    for (final size in sizes.entries) {
      testWidgets('capture ${state.key} at ${size.key}', (tester) async {
        tester.view.physicalSize = size.value;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          RepaintBoundary(
            key: const ValueKey('enterprise-state-capture'),
            child: MaterialApp(
              theme: AppTheme.light(),
              home: Scaffold(body: SafeArea(child: state.value)),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byKey(const ValueKey('enterprise-state-capture')),
          matchesGoldenFile(
            Uri.file('$output/state-${state.key}-${size.key}.png'),
          ),
        );
      }, skip: output.isEmpty);
    }
  }
}
