import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:india_trading_app/theme/app_theme.dart';
import 'package:india_trading_app/widgets/home/home_section_header.dart';

void main() {
  testWidgets(
    'section header exposes view-all semantics only when actionable',
    (tester) async {
      var opened = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                const HomeSectionHeader(title: 'Featured'),
                HomeSectionHeader(
                  title: 'Market News',
                  onViewAll: () => opened++,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.bySemanticsLabel('View All Market News'), findsOneWidget);
      expect(find.bySemanticsLabel('View All Featured'), findsNothing);
      final actionSize = tester.getSize(
        find.bySemanticsLabel('View All Market News'),
      );
      expect(actionSize.height, greaterThanOrEqualTo(44));
      await tester.tap(find.bySemanticsLabel('View All Market News'));
      expect(opened, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('section headers wrap at phone width and enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(1.5)),
          child: child!,
        ),
        home: const Scaffold(
          body: Padding(
            padding: EdgeInsets.all(16),
            child: HomeSectionHeader(title: 'Market Indices', onViewAll: _noop),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.bySemanticsLabel('View All Market Indices')).height,
      greaterThanOrEqualTo(44),
    );
  });
}

void _noop() {}
