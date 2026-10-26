import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:india_trading_app/theme/app_theme.dart';
import 'package:india_trading_app/widgets/app_status_scene.dart';
import 'package:india_trading_app/widgets/app_status_timeline.dart';

void main() {
  testWidgets('status scene explains state freshness next step and action', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: AppStatusScene(
            icon: Icons.hourglass_top_rounded,
            title: 'Documents received',
            message: 'Your documents are waiting for manual review.',
            status: 'Submitted',
            freshness: 'Updated just now',
            nextStep: 'We will show the review result here.',
            primaryAction: AppStatusAction(
              label: 'View status',
              onPressed: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Documents received'), findsOneWidget);
    expect(find.text('Submitted'), findsOneWidget);
    expect(find.text('Updated just now'), findsOneWidget);
    expect(find.text('We will show the review result here.'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'View status'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('timeline exposes current completed and upcoming steps', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: AppStatusTimeline(
            steps: [
              AppStatusStep(label: 'Submitted', state: AppStatusStepState.done),
              AppStatusStep(
                label: 'Manual review',
                state: AppStatusStepState.current,
              ),
              AppStatusStep(label: 'Result'),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Submitted'), findsOneWidget);
    expect(find.text('Manual review'), findsOneWidget);
    expect(find.text('Result'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
