import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:india_trading_app/pages/product_portfolio_page.dart';
import 'package:india_trading_app/theme/app_theme.dart';

Map<String, dynamic> fixture({bool empty = false}) => {
  'asOf': '2026-09-10T10:00:00Z',
  'positionCount': empty ? 0 : 1,
  'currentValue': empty ? 0 : 120,
  'invested': empty ? 0 : 100,
  'totalPnl': empty ? 0 : 20,
  'realizedPnl': 0,
  'unrealizedPnl': empty ? 0 : 20,
  'bestSegment': empty ? null : 'Institutional',
  'history': {
    'points': empty
        ? []
        : [
            {'productValue': 100},
            {'productValue': 120},
          ],
    'productProfitChange': empty ? null : 20,
  },
  'activity': [],
  'categories': [
    for (final category in ['Institutional', 'OTC', 'IPO'])
      {
        'category': category,
        'currentValue': !empty && category == 'Institutional' ? 120 : 0,
        'invested': !empty && category == 'Institutional' ? 100 : 0,
        'totalPnl': !empty && category == 'Institutional' ? 20 : 0,
        'allocationPercent': !empty && category == 'Institutional' ? 100 : 0,
        'positions': [],
      },
  ],
};
void main() {
  Widget app(
    Future<Map<String, dynamic>> Function(String) loader, {
    VoidCallback? onExplore,
    VoidCallback? onSearch,
    VoidCallback? onNotifications,
    int notificationCount = 0,
  }) => MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: ProductPortfolioPage(
        loader: loader,
        onExplore: onExplore ?? () {},
        onNotifications: onNotifications ?? () {},
        notificationCount: notificationCount,
        onSearch: onSearch,
      ),
    ),
  );
  testWidgets('portfolio search calls the existing search entry', (
    tester,
  ) async {
    var searches = 0;
    await tester.pumpWidget(
      app((_) async => fixture(), onSearch: () => searches++),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Search stocks'));
    expect(searches, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets('portfolio notification badge preserves the button callback', (
    tester,
  ) async {
    var opened = 0;
    await tester.pumpWidget(
      app(
        (_) async => fixture(),
        notificationCount: 12,
        onNotifications: () => opened++,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('9+'), findsOneWidget);
    await tester.tapAt(tester.getCenter(find.text('9+')));
    expect(opened, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'empty account shows an actionable empty state without a zero donut',
    (tester) async {
      var explored = false;
      await tester.pumpWidget(
        app(
          (_) async => fixture(empty: true),
          onExplore: () => explored = true,
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('View Investment Offers'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(find.text('100%'), findsNothing);
      await tester.tap(find.text('View Investment Offers'));
      expect(explored, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('period errors never retain a chart for the wrong period', (
    tester,
  ) async {
    await tester.pumpWidget(
      app((period) async {
        if (period == '1D') throw Exception('offline');
        return fixture();
      }),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('1D'));
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Total Portfolio Value'), findsNothing);
  });
  testWidgets('refresh failure keeps the last successful portfolio visible', (
    tester,
  ) async {
    var failRefresh = false;
    await tester.pumpWidget(
      app((_) async {
        if (failRefresh) throw Exception('offline');
        return fixture();
      }),
    );
    await tester.pumpAndSettle();
    expect(find.text('Total Portfolio Value'), findsOneWidget);

    failRefresh = true;
    final refresh = tester.widget<RefreshIndicator>(
      find.byType(RefreshIndicator),
    );
    await refresh.onRefresh();
    await tester.pumpAndSettle();

    expect(find.text('Total Portfolio Value'), findsOneWidget);
    expect(
      find.text('Showing previously loaded portfolio data.'),
      findsOneWidget,
    );
    expect(find.textContaining('offline'), findsOneWidget);
  });
  testWidgets('portfolio period controls follow the value and chart', (
    tester,
  ) async {
    await tester.pumpWidget(app((_) async => fixture()));
    await tester.pumpAndSettle();
    final value = tester.getRect(find.text('Total Portfolio Value'));
    final period = tester.getRect(
      find.byKey(const ValueKey('portfolio-period-1M')),
    );
    expect(period.top, greaterThan(value.bottom));
    expect(tester.takeException(), isNull);
  });
  testWidgets('allocation keeps donut, percentage, legend, and progress bars', (
    tester,
  ) async {
    await tester.pumpWidget(app((_) async => fixture()));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Asset Allocation'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    final allocationPaint = find.byWidgetPredicate(
      (widget) =>
          widget is CustomPaint &&
          widget.painter.runtimeType.toString() == '_AllocationPainter',
      description: 'portfolio allocation donut painter',
    );
    expect(allocationPaint, findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('Institutional'), findsWidgets);
    expect(find.text('OTC'), findsWidgets);
    expect(find.text('IPO'), findsWidgets);
    expect(find.byType(LinearProgressIndicator), findsWidgets);
    expect(
      find.bySemanticsLabel(RegExp(r'Asset Allocation.*100%')),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        RegExp(r'Institutional[\s\S]*Allocation[\s\S]*100'),
      ),
      findsWidgets,
    );
  });
  testWidgets('late period responses are ignored after disposal', (
    tester,
  ) async {
    final first = Completer<Map<String, dynamic>>();
    var calls = 0;
    await tester.pumpWidget(
      app((_) {
        calls++;
        return calls == 2
            ? first.future
            : Future.value(fixture(empty: calls == 3));
      }),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('1D'));
    await tester.pump();
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    first.complete(fixture());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  for (final width in [320.0, 390.0, 1200.0]) {
    testWidgets('populated portfolio fits width $width', (tester) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(app((_) async => fixture()));
      await tester.pumpAndSettle();
      for (var i = 0; i < 5; i++) {
        await tester.drag(find.byType(ListView).first, const Offset(0, -250));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });
  }
}
