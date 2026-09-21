import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:india_trading_app/models/deposit_request.dart';
import 'package:india_trading_app/pages/deposit_page.dart';
import 'package:india_trading_app/services/trading_service.dart';
import 'package:india_trading_app/theme/app_theme.dart';
import 'package:india_trading_app/utils/number_formatters.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeDepositService extends TradingService {
  FakeDepositService(this._handler);

  Future<List<DepositRequest>> Function() _handler;
  int calls = 0;

  void updateHandler(Future<List<DepositRequest>> Function() handler) {
    _handler = handler;
  }

  @override
  Future<List<DepositRequest>> fetchMyDeposits() {
    calls += 1;
    return _handler();
  }
}

Widget host(
  Widget child, {
  Size size = const Size(390, 844),
  double textScale = 1,
  bool reduceMotion = false,
}) {
  return MaterialApp(
    theme: AppTheme.light(),
    builder: (context, content) {
      final media = MediaQuery.of(context);
      return MediaQuery(
        data: media.copyWith(
          size: size,
          textScaler: TextScaler.linear(textScale),
          disableAnimations: reduceMotion,
          accessibleNavigation: reduceMotion,
        ),
        child: content!,
      );
    },
    home: child,
  );
}

void setView(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

DepositRequest sampleDeposit({
  String id = 'dep-1',
  double amount = 1500,
  String status = 'APPROVED',
}) {
  return DepositRequest(
    id: id,
    amount: amount,
    status: status,
    createdAt: DateTime.utc(2026, 9, 10, 10),
    paymentMethod: 'BANK',
    referenceId: 'ref-1',
  );
}

Future<void> pumpDeposit(
  WidgetTester tester, {
  required FakeDepositService service,
  Size size = const Size(390, 844),
  double textScale = 1,
  bool reduceMotion = false,
}) async {
  SharedPreferences.setMockInitialValues({});
  setView(tester, size);
  await tester.pumpWidget(
    host(
      DepositPage(tradingService: service),
      size: size,
      textScale: textScale,
      reduceMotion: reduceMotion,
    ),
  );
}

void main() {
  testWidgets('first load shows loading not empty', (tester) async {
    final gate = Completer<List<DepositRequest>>();
    final service = FakeDepositService(() => gate.future);
    await pumpDeposit(tester, service: service);
    await tester.pump();
    expect(find.text('Loading deposit history'), findsOneWidget);
    expect(find.text('No deposit records yet.'), findsNothing);
    expect(find.text('Unable to load deposit history'), findsNothing);
    gate.complete(const []);
    await tester.pumpAndSettle();
  });

  testWidgets('empty history is distinct from error', (tester) async {
    final service = FakeDepositService(() async => const []);
    await pumpDeposit(tester, service: service);
    await tester.pumpAndSettle();
    expect(find.text('No deposit records yet.'), findsOneWidget);
    expect(find.text('Unable to load deposit history'), findsNothing);
    expect(find.text('Contact customer support'), findsWidgets);
    expect(find.text('Retry'), findsNothing);
    expect(
      find.textContaining('Deposits are not submitted inside the app'),
      findsOneWidget,
    );
  });

  testWidgets('records show server amount and status', (tester) async {
    final service = FakeDepositService(() async => [sampleDeposit()]);
    await pumpDeposit(tester, service: service);
    await tester.pumpAndSettle();
    expect(find.text(formatPrice(1500)), findsOneWidget);
    expect(find.textContaining('Approved'), findsWidgets);
    expect(find.text('No deposit records yet.'), findsNothing);
  });

  testWidgets('failed load shows error not empty', (tester) async {
    final service = FakeDepositService(
      () async => throw const TradingException(
        'Unable to load deposit history. Please try again.',
      ),
    );
    await pumpDeposit(tester, service: service);
    await tester.pumpAndSettle();
    expect(find.text('Unable to load deposit history'), findsWidgets);
    expect(find.text('No deposit records yet.'), findsNothing);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('retry succeeds without a duplicate in-flight request', (
    tester,
  ) async {
    final gate = Completer<List<DepositRequest>>();
    var phase = 0;
    final service = FakeDepositService(() {
      if (phase == 0) {
        return Future<List<DepositRequest>>.error(
          const TradingException('offline'),
        );
      }
      return gate.future;
    });
    await pumpDeposit(tester, service: service);
    await tester.pumpAndSettle();
    expect(service.calls, 1);
    phase = 1;
    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(service.calls, 2);
    await tester.tap(find.byTooltip('Refresh deposit history'));
    await tester.pump();
    expect(service.calls, 2);
    gate.complete([sampleDeposit(amount: 200)]);
    await tester.pumpAndSettle();
    expect(find.text(formatPrice(200)), findsOneWidget);
    expect(service.calls, 2);
  });

  testWidgets('pull-to-refresh reuses the load path', (tester) async {
    final service = FakeDepositService(() async => const []);
    await pumpDeposit(tester, service: service);
    await tester.pumpAndSettle();
    expect(service.calls, 1);
    await tester.fling(find.byType(ListView), const Offset(0, 300), 1000);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(service.calls, 2);
  });

  testWidgets('disposed page ignores a late response', (tester) async {
    final gate = Completer<List<DepositRequest>>();
    final service = FakeDepositService(() => gate.future);
    await pumpDeposit(tester, service: service);
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    gate.complete([sampleDeposit()]);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('page has support CTA and no client deposit submit', (
    tester,
  ) async {
    final service = FakeDepositService(() async => const []);
    await pumpDeposit(
      tester,
      service: service,
      size: const Size(320, 568),
      textScale: 1.5,
      reduceMotion: true,
    );
    await tester.pumpAndSettle();
    expect(find.text('Contact customer support'), findsWidgets);
    expect(find.textContaining('finance credits your account'), findsOneWidget);
    expect(find.text('Submit deposit'), findsNothing);
    expect(find.text('Request deposit'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('parses decimal amount strings from GET /deposit/me', () {
    final row = DepositRequest.fromJson({
      'id': 'abc',
      'amount': '2500.50',
      'status': 'PENDING',
      'createdAt': '2026-09-10T04:30:00.000Z',
      'paymentMethod': 'BANK',
      'referenceId': 'r1',
      'note': null,
    });
    expect(row.amount, 2500.50);
    expect(row.status, 'PENDING');
    expect(row.note, isNull);
  });
}
