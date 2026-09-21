import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:india_trading_app/models/deposit_request.dart';
import 'package:india_trading_app/models/institutional_opportunity.dart';
import 'package:india_trading_app/models/ipo.dart';
import 'package:india_trading_app/models/withdrawal_request.dart';
import 'package:india_trading_app/pages/deposit_page.dart';
import 'package:india_trading_app/pages/loan_page.dart';
import 'package:india_trading_app/pages/withdrawal_page.dart';
import 'package:india_trading_app/services/auth_service.dart';
import 'package:india_trading_app/services/client_account_service.dart';
import 'package:india_trading_app/services/otc_service.dart';
import 'package:india_trading_app/services/trading_service.dart';
import 'package:india_trading_app/theme/app_theme.dart';
import 'package:india_trading_app/widgets/trading/ipo_tab.dart';
import 'package:india_trading_app/widgets/trading/otc_tab.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _output = String.fromEnvironment('UI_CAPTURE_DIR');

class _DepositService extends TradingService {
  _DepositService(this.handler);
  final Future<List<DepositRequest>> Function() handler;
  @override
  Future<List<DepositRequest>> fetchMyDeposits() => handler();
}

class _AccountService extends ClientAccountService {
  @override
  Future<bool> hasWithdrawalPin() async => true;
  @override
  Future<List<Map<String, dynamic>>> banks() async => [
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

class _AuthService extends AuthService {
  _AuthService(this.handler);
  final Future<List<WithdrawalRequest>> Function() handler;
  @override
  Future<List<WithdrawalRequest>> fetchWithdrawals() => handler();
}

class _LoanService extends ClientAccountService {
  _LoanService(this.handler);
  final Future<List<Map<String, dynamic>>> Function() handler;
  @override
  Future<List<Map<String, dynamic>>> loans() => handler();
}

class _OtcService extends OtcService {
  _OtcService(this.offerFn, this.orderFn);
  final Future<List<InstitutionalStock>> Function() offerFn;
  final Future<List<OtcOrderRecord>> Function() orderFn;
  @override
  Future<List<InstitutionalStock>> offers() => offerFn();
  @override
  Future<List<OtcOrderRecord>> orders() => orderFn();
}

WithdrawalRequest _withdrawal() => WithdrawalRequest(
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

DepositRequest _deposit() => DepositRequest(
  id: 'd1',
  amount: 1500,
  status: 'APPROVED',
  createdAt: DateTime.utc(2026, 9, 10, 10),
  paymentMethod: 'BANK',
  referenceId: 'ref-1',
);

Ipo _ipo() => const Ipo(
  id: 'ipo1',
  companyName: 'Acme',
  symbol: 'ACM',
  status: IpoStatus.open,
  marketPrice: 120,
  subscriptionPrice: 100,
  lotSize: 10,
);

InstitutionalStock _offer() => const InstitutionalStock(
  id: 'o1',
  symbol: 'ACME',
  companyName: 'Acme OTC',
  price: 90,
  marketPrice: 100,
  status: 'ACTIVE',
);

OtcOrderRecord _otcPending() => OtcOrderRecord(
  id: 'ord1',
  orderNo: 'OTC1',
  symbol: 'ACME',
  quantity: 2,
  price: 90,
  status: 'PENDING',
  createdAt: DateTime.utc(2026, 9, 12),
);

Widget _host(Size size, Widget home, {double scale = 1}) {
  return MaterialApp(
    theme: AppTheme.light(),
    debugShowCheckedModeBanner: false,
    builder: (context, content) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        size: size,
        textScaler: TextScaler.linear(scale),
        disableAnimations: true,
      ),
      child: content!,
    ),
    home: home,
  );
}

Future<void> _capture(
  WidgetTester tester,
  String name,
  Size size,
  Widget home, {
  bool settle = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(
    RepaintBoundary(key: const ValueKey('capture'), child: _host(size, home)),
  );
  if (settle) {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  } else {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('capture')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory(_output).createSync(recursive: true);
    File('$_output/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
  await tester.pumpWidget(const SizedBox.shrink());
}

void main() {
  final skip = _output.isEmpty;
  const sizes = <String, Size>{
    '320': Size(320, 568),
    '390': Size(390, 844),
    '414': Size(414, 896),
    '768': Size(768, 1024),
  };

  test('writes j2 funds screenshots', () async {}, skip: skip);

  if (skip) return;

  for (final entry in sizes.entries) {
    testWidgets('deposit states ${entry.key}', (tester) async {
      final loading = Completer<List<DepositRequest>>();
      await _capture(
        tester,
        'deposit-loading-${entry.key}',
        entry.value,
        DepositPage(tradingService: _DepositService(() => loading.future)),
        settle: false,
      );
      loading.complete(const []);

      await _capture(
        tester,
        'deposit-empty-${entry.key}',
        entry.value,
        DepositPage(tradingService: _DepositService(() async => const [])),
      );
      await _capture(
        tester,
        'deposit-error-${entry.key}',
        entry.value,
        DepositPage(
          tradingService: _DepositService(
            () async => throw const TradingException('offline'),
          ),
        ),
      );
      await _capture(
        tester,
        'deposit-status-${entry.key}',
        entry.value,
        DepositPage(tradingService: _DepositService(() async => [_deposit()])),
      );
    });

    testWidgets('withdrawal states ${entry.key}', (tester) async {
      final loading = Completer<List<WithdrawalRequest>>();
      await _capture(
        tester,
        'withdrawal-loading-${entry.key}',
        entry.value,
        WithdrawalPage(
          availableBalance: 1000,
          frozenBalance: 0,
          authService: _AuthService(() => loading.future),
          accountService: _AccountService(),
        ),
        settle: false,
      );
      loading.complete(const []);

      await _capture(
        tester,
        'withdrawal-empty-${entry.key}',
        entry.value,
        WithdrawalPage(
          availableBalance: 1000,
          frozenBalance: 0,
          authService: _AuthService(() async => const []),
          accountService: _AccountService(),
        ),
      );
      await _capture(
        tester,
        'withdrawal-error-${entry.key}',
        entry.value,
        WithdrawalPage(
          availableBalance: 1000,
          frozenBalance: 0,
          authService: _AuthService(
            () async => throw const AuthException('offline'),
          ),
          accountService: _AccountService(),
        ),
      );
      await _capture(
        tester,
        'withdrawal-status-${entry.key}',
        entry.value,
        WithdrawalPage(
          availableBalance: 1000,
          frozenBalance: 0,
          authService: _AuthService(() async => [_withdrawal()]),
          accountService: _AccountService(),
        ),
      );
    });

    testWidgets('loan states ${entry.key}', (tester) async {
      final loading = Completer<List<Map<String, dynamic>>>();
      await _capture(
        tester,
        'loan-loading-${entry.key}',
        entry.value,
        LoanPage(service: _LoanService(() => loading.future)),
        settle: false,
      );
      loading.complete(const []);

      await _capture(
        tester,
        'loan-empty-${entry.key}',
        entry.value,
        LoanPage(service: _LoanService(() async => const [])),
      );
      await _capture(
        tester,
        'loan-error-${entry.key}',
        entry.value,
        LoanPage(
          service: _LoanService(
            () async => throw const AuthException('offline'),
          ),
        ),
      );
      await _capture(
        tester,
        'loan-status-${entry.key}',
        entry.value,
        LoanPage(
          service: _LoanService(
            () async => [
              {
                'orderNo': 'LN9',
                'status': 'PENDING',
                'createdAt': '2026-09-21T04:00:00.000Z',
              },
            ],
          ),
        ),
      );
    });

    testWidgets('ipo states ${entry.key}', (tester) async {
      await _capture(
        tester,
        'ipo-empty-${entry.key}',
        entry.value,
        Scaffold(
          body: IpoTab(ipos: const [], applications: const [], onApply: (_) {}),
        ),
      );
      await _capture(
        tester,
        'ipo-error-${entry.key}',
        entry.value,
        Scaffold(
          body: IpoTab(
            ipos: const [],
            applications: const [],
            onApply: (_) {},
            loadFailed: true,
            onRetry: () async {},
          ),
        ),
      );
      await _capture(
        tester,
        'ipo-status-${entry.key}',
        entry.value,
        Scaffold(
          body: IpoTab(ipos: [_ipo()], applications: const [], onApply: (_) {}),
        ),
      );
    });

    testWidgets('otc states ${entry.key}', (tester) async {
      final loading = Completer<List<InstitutionalStock>>();
      await _capture(
        tester,
        'otc-loading-${entry.key}',
        entry.value,
        Scaffold(
          body: OtcTab(
            service: _OtcService(() => loading.future, () async => const []),
          ),
        ),
        settle: false,
      );
      loading.complete(const []);

      await _capture(
        tester,
        'otc-empty-${entry.key}',
        entry.value,
        Scaffold(
          body: OtcTab(
            service: _OtcService(() async => const [], () async => const []),
          ),
        ),
      );
      await _capture(
        tester,
        'otc-error-${entry.key}',
        entry.value,
        Scaffold(
          body: OtcTab(
            service: _OtcService(
              () async => throw const OtcException('offline'),
              () async => const [],
            ),
          ),
        ),
      );
      await _capture(
        tester,
        'otc-status-${entry.key}',
        entry.value,
        Scaffold(
          body: OtcTab(
            service: _OtcService(
              () async => [_offer()],
              () async => [_otcPending()],
            ),
          ),
        ),
      );
    });
  }
}
