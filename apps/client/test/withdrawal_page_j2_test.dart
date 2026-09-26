import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:india_trading_app/models/withdrawal_request.dart';
import 'package:india_trading_app/pages/withdrawal_page.dart';
import 'package:india_trading_app/services/auth_service.dart';
import 'package:india_trading_app/services/client_account_service.dart';
import 'package:india_trading_app/services/trading_service.dart';
import 'package:india_trading_app/theme/app_theme.dart';
import 'package:india_trading_app/utils/number_formatters.dart';

class FakeAccount extends ClientAccountService {
  FakeAccount({this.pin = true, this.bankRows});
  bool pin;
  List<Map<String, dynamic>>? bankRows;
  @override
  Future<bool> hasWithdrawalPin() async => pin;
  @override
  Future<List<Map<String, dynamic>>> banks() async =>
      bankRows ??
      [
        {
          'id': 'b1',
          'bankName': 'HDFC',
          'accountNumber': '1234567890',
          'ifscCode': 'HDFC0001',
          'accountHolder': 'Priya',
          'isPrimary': true,
          'status': 'Added',
        },
      ];
}

class FakeAuth extends AuthService {
  FakeAuth({this.listFn});
  Future<List<WithdrawalRequest>> Function()? listFn;
  final rows = <WithdrawalRequest>[];
  int fetches = 0;
  int submits = 0;
  @override
  Future<List<WithdrawalRequest>> fetchWithdrawals() {
    fetches += 1;
    if (listFn != null) return listFn!();
    return Future.value(List.of(rows));
  }

  @override
  Future<WithdrawalRequest> submitWithdrawal({
    required String withdrawalPin,
    required double amount,
    required String bankName,
    required String accountNumber,
    required String ifscCode,
    String? note,
    String? idempotencyKey,
  }) async {
    submits += 1;
    if (withdrawalPin != '123456') {
      throw const AuthException('Incorrect PIN');
    }
    final request = WithdrawalRequest(
      id: 'w1',
      orderNo: 'WD1',
      amount: amount,
      bankName: bankName,
      accountHolderName: 'Priya',
      maskedAccountNumber: '****7890',
      ifscCode: ifscCode,
      status: WithdrawalStatus.pending,
      createdAt: DateTime.utc(2026, 9, 21),
    );
    rows.insert(0, request);
    return request;
  }
}

class SnapshotTrading extends TradingService {
  @override
  Future<TradingAccountSnapshot?> fetchAccountSnapshot({
    bool allowCached = true,
  }) async => TradingAccountSnapshot.fromJson({
    'balances': {
      'cashBalance': '900.00',
      'buyingPower': '900.00',
      'frozenBalance': '100.00',
    },
    'pnl': {'realizedPnl': '0'},
    'positions': [],
  });
}

Widget host(
  Widget child, {
  Size size = const Size(390, 844),
  double scale = 1,
  bool reduceMotion = false,
}) {
  return MaterialApp(
    theme: AppTheme.light(),
    builder: (context, content) {
      return MediaQuery(
        data: MediaQuery.of(context).copyWith(
          size: size,
          textScaler: TextScaler.linear(scale),
          disableAnimations: reduceMotion,
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

WithdrawalRequest sample() => WithdrawalRequest(
  id: 'w0',
  orderNo: 'WD0',
  amount: 250,
  bankName: 'HDFC',
  accountHolderName: 'Priya',
  maskedAccountNumber: '****7890',
  ifscCode: 'HDFC0001',
  status: WithdrawalStatus.pending,
  createdAt: DateTime.utc(2026, 9, 10),
);

void main() {
  testWidgets('loading is not empty', (tester) async {
    final gate = Completer<List<WithdrawalRequest>>();
    final auth = FakeAuth(listFn: () => gate.future);
    setView(tester, const Size(320, 568));
    await tester.pumpWidget(
      host(
        WithdrawalPage(
          availableBalance: 1000,
          frozenBalance: 0,
          authService: auth,
          accountService: FakeAccount(),
        ),
        size: const Size(320, 568),
        scale: 1.3,
      ),
    );
    await tester.pump();
    expect(find.text('Loading withdrawals'), findsOneWidget);
    expect(find.text('No withdrawal records yet.'), findsNothing);
    gate.complete(const []);
    await tester.pumpAndSettle();
  });

  testWidgets('error is not empty', (tester) async {
    final auth = FakeAuth(
      listFn: () async => throw const AuthException('offline'),
    );
    setView(tester, const Size(390, 844));
    await tester.pumpWidget(
      host(
        WithdrawalPage(
          availableBalance: 1000,
          frozenBalance: 0,
          authService: auth,
          accountService: FakeAccount(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Unable to load withdrawals'), findsWidgets);
    expect(find.text('No withdrawal records yet.'), findsNothing);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('retry does not duplicate in-flight load', (tester) async {
    final gate = Completer<List<WithdrawalRequest>>();
    var phase = 0;
    final auth = FakeAuth(
      listFn: () {
        if (phase == 0) {
          return Future<List<WithdrawalRequest>>.error(
            const AuthException('offline'),
          );
        }
        return gate.future;
      },
    );
    await tester.pumpWidget(
      host(
        WithdrawalPage(
          availableBalance: 1000,
          frozenBalance: 0,
          authService: auth,
          accountService: FakeAccount(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(auth.fetches, 1);
    phase = 1;
    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(auth.fetches, 2);
    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(auth.fetches, 2);
    gate.complete([sample()]);
    await tester.pumpAndSettle();
    expect(find.text('WD0'), findsOneWidget);
  });

  testWidgets('refresh failure keeps prior data and shows stale notice', (
    tester,
  ) async {
    var failRefresh = false;
    final auth = FakeAuth(
      listFn: () async {
        if (failRefresh) throw const AuthException('offline');
        return [sample()];
      },
    );
    await tester.pumpWidget(
      host(
        WithdrawalPage(
          availableBalance: 1000,
          frozenBalance: 0,
          authService: auth,
          accountService: FakeAccount(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('WD0'), findsOneWidget);

    failRefresh = true;
    await tester.tap(find.byTooltip('Refresh withdrawal history'));
    await tester.pumpAndSettle();

    expect(find.text('WD0'), findsOneWidget);
    expect(
      find.textContaining('Showing previously loaded data'),
      findsOneWidget,
    );
    expect(find.textContaining('offline'), findsOneWidget);
  });

  testWidgets('submit keeps input on failure and only succeeds after server', (
    tester,
  ) async {
    final auth = FakeAuth();
    setView(tester, const Size(390, 844));
    await tester.pumpWidget(
      host(
        WithdrawalPage(
          availableBalance: 5000,
          frozenBalance: 10,
          authService: auth,
          accountService: FakeAccount(),
          tradingService: SnapshotTrading(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), '150');
    await tester.enterText(find.byType(TextField).at(1), '000000');
    await tester.ensureVisible(find.text('Submit Request'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit Request'));
    await tester.pumpAndSettle();
    expect(auth.submits, 1);
    expect(find.text('WD1'), findsNothing);
    expect(find.text('150'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(1), '123456');
    await tester.ensureVisible(find.text('Submit Request'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit Request'));
    await tester.pumpAndSettle();
    expect(auth.submits, 2);
    expect(find.text('WD1'), findsOneWidget);
    expect(find.textContaining('Submit deposit'), findsNothing);
  });

  testWidgets('no self-serve deposit and 768 layout', (tester) async {
    setView(tester, const Size(768, 1024));
    await tester.pumpWidget(
      host(
        WithdrawalPage(
          availableBalance: 0,
          frozenBalance: 0,
          authService: FakeAuth(listFn: () async => [sample()]),
          accountService: FakeAccount(),
        ),
        size: const Size(768, 1024),
        scale: 1.5,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('WD0'), findsOneWidget);
    expect(find.text(formatPrice(250)), findsWidgets);
    expect(find.text('Pending'), findsWidgets);
    expect(find.text('Submit deposit'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('disposed load does not throw', (tester) async {
    final gate = Completer<List<WithdrawalRequest>>();
    await tester.pumpWidget(
      host(
        WithdrawalPage(
          availableBalance: 1000,
          frozenBalance: 0,
          authService: FakeAuth(listFn: () => gate.future),
          accountService: FakeAccount(),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    gate.complete([sample()]);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion empty state at 414', (tester) async {
    setView(tester, const Size(414, 896));
    await tester.pumpWidget(
      host(
        WithdrawalPage(
          availableBalance: 1000,
          frozenBalance: 0,
          authService: FakeAuth(listFn: () async => const []),
          accountService: FakeAccount(),
        ),
        size: const Size(414, 896),
        scale: 1.3,
        reduceMotion: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No withdrawal records yet.'), findsOneWidget);
    expect(find.text('Submit Request'), findsOneWidget);
    expect(find.text('Submit deposit'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
