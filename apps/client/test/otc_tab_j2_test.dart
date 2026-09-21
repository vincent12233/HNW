import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:india_trading_app/models/institutional_opportunity.dart';
import 'package:india_trading_app/services/otc_service.dart';
import 'package:india_trading_app/theme/app_theme.dart';
import 'package:india_trading_app/widgets/trading/otc_tab.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeOtc extends OtcService {
  FakeOtc(this.offerFn, this.orderFn, {this.onSubmit});
  final Future<List<InstitutionalStock>> Function() offerFn;
  final Future<List<OtcOrderRecord>> Function() orderFn;
  final Future<OtcOrderRecord> Function(String, int, String)? onSubmit;
  int offerCalls = 0;
  int submits = 0;

  @override
  Future<List<InstitutionalStock>> offers() {
    offerCalls += 1;
    return offerFn();
  }

  @override
  Future<List<OtcOrderRecord>> orders() => orderFn();

  @override
  Future<OtcOrderRecord> submit(String offerId, int quantity, String key) {
    submits += 1;
    return onSubmit?.call(offerId, quantity, key) ??
        Future.error(const OtcException('PIN rejected'));
  }
}

InstitutionalStock offer() => const InstitutionalStock(
  id: 'o1',
  symbol: 'ACME',
  companyName: 'Acme OTC',
  price: 90,
  marketPrice: 100,
  status: 'ACTIVE',
);

OtcOrderRecord pending() => OtcOrderRecord(
  id: 'ord1',
  orderNo: 'OTC1',
  symbol: 'ACME',
  quantity: 2,
  price: 90,
  status: 'PENDING',
  createdAt: DateTime.utc(2026, 9, 12),
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
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('OTC loading is not empty', (tester) async {
    final gate = Completer<List<InstitutionalStock>>();
    await tester.pumpWidget(
      host(OtcTab(service: FakeOtc(() => gate.future, () async => const []))),
    );
    await tester.pump();
    expect(find.text('Loading OTC orders'), findsOneWidget);
    expect(find.text('No OTC opportunities available'), findsNothing);
    gate.complete(const []);
    await tester.pumpAndSettle();
  });

  testWidgets('OTC error is not empty', (tester) async {
    await tester.pumpWidget(
      host(
        OtcTab(
          service: FakeOtc(
            () async => throw const OtcException('offline'),
            () async => const [],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Unable to load OTC'), findsOneWidget);
    expect(find.text('No OTC opportunities available'), findsNothing);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('OTC pending is not treated as settled', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      host(
        OtcTab(
          service: FakeOtc(() async => [offer()], () async => [pending()]),
        ),
        size: const Size(320, 568),
        scale: 1.5,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Pending review'), findsWidgets);
    expect(find.textContaining('In holdings'), findsNothing);
    expect(find.textContaining('settled'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed OTC submit keeps quantity and does not add an order', (
    tester,
  ) async {
    final service = FakeOtc(
      () async => [offer()],
      () async => const [],
      onSubmit: (_, _, _) async => throw const OtcException('PIN rejected'),
    );
    await tester.pumpWidget(host(OtcTab(service: service)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trade Now'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Quantity'), '3');
    await tester.enterText(
      find.widgetWithText(TextField, '4-digit transaction PIN'),
      '1111',
    );
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();
    expect(service.submits, 1);
    expect(find.text('OTC1'), findsNothing);
    expect(find.text('Pending review'), findsNothing);
  });

  testWidgets('OTC reduced motion error keeps retry at 414', (tester) async {
    tester.view.physicalSize = const Size(414, 896);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      host(
        OtcTab(
          service: FakeOtc(
            () async => throw const OtcException('offline'),
            () async => const [],
          ),
        ),
        size: const Size(414, 896),
        scale: 1.3,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Unable to load OTC'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
