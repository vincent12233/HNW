import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:india_trading_app/theme/app_theme.dart';
import 'package:india_trading_app/widgets/app_status_scene.dart';
import 'package:india_trading_app/widgets/app_status_timeline.dart';

void main() {
  testWidgets('manual review status visual baseline', (tester) async {
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
                icon: Icons.fact_check_outlined,
                title: 'Documents received',
                message: 'Your KYC documents are waiting for manual review.',
                status: 'Submitted',
                freshness: 'Updated just now',
                nextStep: 'The result will appear here after review.',
                timeline: AppStatusTimeline(
                  steps: [
                    AppStatusStep(
                      label: 'Submitted',
                      state: AppStatusStepState.done,
                    ),
                    AppStatusStep(
                      label: 'Manual review',
                      state: AppStatusStepState.current,
                    ),
                    AppStatusStep(label: 'Result'),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await expectLater(
      find.byKey(const ValueKey('golden')),
      matchesGoldenFile('kyc_manual_review_390x844.png'),
    );
  });

  testWidgets('Hindi enlarged-text review status visual baseline', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(1.4),
            disableAnimations: true,
            accessibleNavigation: true,
          ),
          child: child!,
        ),
        home: const Scaffold(
          body: RepaintBoundary(
            key: ValueKey('hindi-golden'),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: AppStatusScene(
                icon: Icons.fact_check_outlined,
                title: 'दस्तावेज़ प्राप्त हुए',
                message: 'आपके KYC दस्तावेज़ मैन्युअल समीक्षा में हैं।',
                status: 'जमा किया गया',
                freshness: 'अभी अपडेट किया गया',
                nextStep: 'समीक्षा पूरी होने पर परिणाम यहाँ दिखाई देगा।',
              ),
            ),
          ),
        ),
      ),
    );
    await expectLater(
      find.byKey(const ValueKey('hindi-golden')),
      matchesGoldenFile('kyc_review_hi_text_1_4_390x844.png'),
    );
  });
}
