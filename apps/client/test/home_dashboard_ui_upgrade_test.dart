import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

      expect(find.bySemanticsLabel('View all Market News'), findsOneWidget);
      expect(find.bySemanticsLabel('View all Featured'), findsNothing);
      final actionSize = tester.getSize(
        find.bySemanticsLabel('View all Market News'),
      );
      expect(actionSize.height, greaterThanOrEqualTo(44));
      await tester.tap(find.bySemanticsLabel('View all Market News'));
      expect(opened, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
