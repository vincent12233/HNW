import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:india_trading_app/models/ipo.dart';
import 'package:india_trading_app/theme/app_theme.dart';
import 'package:india_trading_app/widgets/trading/ipo_tab.dart';
import 'package:india_trading_app/widgets/trading/pending_center_tab.dart';
import 'package:shared_preferences/shared_preferences.dart';

Ipo openIpo() => Ipo(
  id: 'ipo1',
  companyName: 'Acme',
  symbol: 'ACM',
  status: IpoStatus.open,
  marketPrice: 120,
  subscriptionPrice: 100,
  lotSize: 10,
);

IpoApplication applied() => const IpoApplication(
  id: 'a1',
  ipoId: 'ipo1',
  companyName: 'Acme',
  symbol: 'ACM',
  appliedQuantity: 10,
  allocatedQuantity: 0,
  subscriptionPrice: 100,
  paidAmount: 0,
  status: IpoApplicationStatus.applied,
);

Widget host(
  Widget child, {
  Size size = const Size(390, 844),
  double scale = 1,
}) {
  return MaterialApp(
    theme: AppTheme.light(),
    builder: (context, content) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        size: size,
        textScaler: TextScaler.linear(scale),
        disableAnimations: true,
      ),
      child: content!,
    ),
    home: Scaffold(body: child),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('IPO load failure is not an empty catalogue', (tester) async {
    await tester.pumpWidget(
      host(
        IpoTab(
          ipos: const [],
          applications: const [],
          onApply: (_) {},
          loadFailed: true,
          onRetry: () async {},
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Unable to load IPOs'), findsOneWidget);
    expect(find.text('No IPOs open for application'), findsNothing);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('open IPO apply does not fire until confirm', (tester) async {
    var applies = 0;
    tester.view.physicalSize = const Size(414, 896);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      host(
        IpoTab(
          ipos: [openIpo()],
          applications: const [],
          onApply: (_) => applies += 1,
        ),
        size: const Size(414, 896),
      ),
    );
    await tester.pump();
    expect(find.text('Apply'), findsWidgets);
    await tester.tap(find.text('Apply').last);
    await tester.pumpAndSettle();
    expect(applies, 0);
    expect(find.text('IPO Application'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(applies, 0);
  });

  testWidgets('applied IPO is not shown as allotted or holdings', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        PendingCenterTab(activeOrders: const [], ipoApplications: [applied()]),
        size: const Size(320, 568),
        scale: 1.3,
      ),
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(ChoiceChip, 'IPO Applications'));
    await tester.pumpAndSettle();
    expect(find.text('Applied'), findsWidgets);
    expect(find.textContaining('added to your holdings'), findsNothing);
    expect(find.textContaining('Outstanding Payment'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('application fetch failure is not empty', (tester) async {
    await tester.pumpWidget(
      host(
        PendingCenterTab(
          activeOrders: const [],
          ipoApplications: const [],
          applicationsFailed: true,
          onRetryApplications: () async {},
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(ChoiceChip, 'IPO Applications'));
    await tester.pumpAndSettle();
    expect(find.text('Unable to load IPO applications'), findsOneWidget);
    expect(find.text('No IPO applications'), findsNothing);
  });

  testWidgets('open IPO fits 768 with reduced motion', (tester) async {
    tester.view.physicalSize = const Size(768, 1024);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      host(
        IpoTab(ipos: [openIpo()], applications: const [], onApply: (_) {}),
        size: const Size(768, 1024),
        scale: 1.5,
      ),
    );
    await tester.pump();
    expect(find.text('Apply'), findsWidgets);
    expect(find.text('Trade Now'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
