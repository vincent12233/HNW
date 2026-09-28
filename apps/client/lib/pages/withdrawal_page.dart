import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_language.dart';
import '../models/async_data_state.dart';
import '../models/withdrawal_request.dart';
import '../pages/account_security_page.dart';
import '../pages/account_settings_page.dart';
import '../services/auth_service.dart';
import '../services/client_account_service.dart';
import '../services/trading_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/client_error_message.dart';
import '../utils/number_formatters.dart';
import '../widgets/app_buttons.dart';
import '../widgets/app_card.dart';
import '../widgets/app_chip.dart';
import '../widgets/app_feedback.dart';
import '../widgets/app_page_scaffold.dart';
import '../widgets/app_status_label.dart';
import '../widgets/record_detail_sheet.dart';

part 'withdrawal_page_cards.dart';

const _minimumWithdrawalAmount = 100.0;

class WithdrawalPage extends StatefulWidget {
  const WithdrawalPage({
    super.key,
    required this.availableBalance,
    required this.frozenBalance,
    this.accountName = '',
    this.authService,
    this.accountService,
    this.tradingService,
    this.onFundsUpdated,
  });

  final double availableBalance;
  final double frozenBalance;
  final String accountName;
  final AuthService? authService;
  final ClientAccountService? accountService;
  final TradingService? tradingService;
  final void Function(
    WithdrawalRequest request,
    TradingAccountSnapshot? snapshot,
  )?
  onFundsUpdated;

  @override
  State<WithdrawalPage> createState() => _WithdrawalPageState();
}

class _WithdrawalPageState extends State<WithdrawalPage> {
  void _setState(VoidCallback fn) => setState(fn);
  late final _auth = widget.authService ?? AuthService();
  late final _account = widget.accountService ?? ClientAccountService();
  late final _trading = widget.tradingService ?? TradingService();
  final _amountController = TextEditingController();
  final _pinController = TextEditingController();

  List<WithdrawalRequest> _history = const [];
  List<Map<String, dynamic>> _banks = const [];
  Map<String, dynamic>? _selectedBank;
  AsyncDataState<List<WithdrawalRequest>> _loadState =
      const AsyncDataState.initial();
  bool _submitting = false;
  bool _hasPin = false;
  String? _formError;
  int _generation = 0;
  Future<void>? _inFlight;
  String? _submissionId;
  late double _available = widget.availableBalance;
  late double _frozen = widget.frozenBalance;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _generation++;
    _amountController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _load() {
    final pending = _inFlight;
    if (pending != null) return pending;
    final request = ++_generation;
    final future = _loadOnce(request);
    _inFlight = future;
    return future.whenComplete(() {
      if (identical(_inFlight, future)) _inFlight = null;
    });
  }

  Future<void> _loadOnce(int request) async {
    final previousState = _loadState;
    if (mounted) {
      setState(() {
        _loadState = AsyncDataState.loading(
          data: previousState.data,
          message: previousState.message,
          updatedAt: previousState.updatedAt,
        );
      });
    }
    try {
      final pin = await _account.hasWithdrawalPin();
      final banks = await _account.banks();
      final history = await _auth.fetchWithdrawals();
      if (!mounted || request != _generation) return;
      Map<String, dynamic>? selected = _selectedBank;
      if (selected == null && banks.isNotEmpty) {
        selected = banks.firstWhere(
          (bank) => bank['isPrimary'] == true,
          orElse: () => banks.first,
        );
      }
      setState(() {
        _hasPin = pin;
        _banks = banks;
        _selectedBank = selected;
        _history = history;
        _loadState = AsyncDataState.success(history);
      });
    } catch (error) {
      if (!mounted || request != _generation) return;
      final message = clientErrorMessage(
        error,
        fallback: 'Unable to load withdrawals. Please try again.',
      );
      setState(() {
        if (_history.isNotEmpty || _banks.isNotEmpty) {
          _loadState = AsyncDataState.stale(
            _history,
            updatedAt: _loadState.updatedAt ?? DateTime.now(),
            message: message,
          );
        } else {
          _loadState = AsyncDataState.error(message);
        }
      });
    }
  }

  Future<void> _submit() async {
    if (_submitting || _loadState.isLoading) return;
    final amount = double.tryParse(
      _amountController.text.trim().replaceAll(',', ''),
    );
    if (amount == null || amount < _minimumWithdrawalAmount) {
      setState(() => _formError = 'Minimum withdrawal amount is ₹100');
      return;
    }
    if (amount > _available) {
      setState(
        () => _formError = 'Maximum available: ${formatPrice(_available)}',
      );
      return;
    }
    final bank = _selectedBank;
    if (bank == null ||
        (bank['accountNumber']?.toString().trim() ?? '').isEmpty ||
        (bank['ifscCode']?.toString().trim() ?? '').isEmpty) {
      setState(() => _formError = 'Select a complete bank account');
      return;
    }
    if (!RegExp(r'^\d{6}$').hasMatch(_pinController.text)) {
      setState(() => _formError = 'Enter a 6-digit PIN');
      return;
    }

    _submissionId ??= AuthService.createClientRequestId('withdrawal');
    setState(() {
      _submitting = true;
      _formError = null;
    });
    try {
      final request = await _auth.submitWithdrawal(
        withdrawalPin: _pinController.text,
        amount: amount,
        bankName: bank['bankName']?.toString() ?? '',
        accountNumber: bank['accountNumber']?.toString() ?? '',
        ifscCode: bank['ifscCode']?.toString() ?? '',
        note: 'App withdrawal request',
        idempotencyKey: _submissionId,
      );
      TradingAccountSnapshot? snapshot;
      try {
        snapshot = await _trading.fetchAccountSnapshot();
      } catch (_) {
        snapshot = null;
      }
      if (!mounted) return;
      widget.onFundsUpdated?.call(request, snapshot);
      if (snapshot != null) {
        _available = snapshot.availableBalance;
        _frozen = snapshot.frozenBalance;
      }
      _submissionId = null;
      _pinController.clear();
      _amountController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: AppText(
            'Withdrawal request ${request.orderNo ?? request.id} submitted. '
            'Funds are frozen while finance reviews it.',
          ),
        ),
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _formError = clientErrorMessage(
          error,
          fallback: 'Unable to submit withdrawal. Please try again.',
        );
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget body;
    if (_loadState.isLoading &&
        _loadState.message == null &&
        _history.isEmpty &&
        _banks.isEmpty) {
      body = const AppLoadingView(message: 'Loading withdrawals');
    } else if ((_loadState.status == AsyncDataStatus.error ||
            (_loadState.isLoading && _loadState.message != null)) &&
        _history.isEmpty &&
        _banks.isEmpty) {
      body = AppErrorView(
        title: 'Unable to load withdrawals',
        message: _loadState.message,
        onRetry: () => unawaited(_load()),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: _loadState.isLoading ? () async {} : _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: AppSpacing.page,
          children: [
            if (_loadState.isLoading)
              const LinearProgressIndicator(minHeight: 2),
            if (_loadState.requiresNotice) _staleDataNotice(),
            _summaryCard(),
            const SizedBox(height: AppSpacing.lg),
            _historyCard(),
            const SizedBox(height: AppSpacing.lg),
            if (!_hasPin)
              _gateCard(
                title: 'Set a withdrawal PIN',
                message:
                    'A 6-digit withdrawal PIN is required before finance can review a request.',
                action: 'Set withdrawal PIN',
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          const AccountSecurityPage(withdrawalPin: true),
                    ),
                  );
                  if (mounted) unawaited(_load());
                },
              )
            else if (_banks.isEmpty)
              _gateCard(
                title: 'Add a bank account',
                message:
                    'Complete your bank account details before withdrawing.',
                action: 'Add bank account',
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          const AccountSettingsPage(section: 'banks'),
                    ),
                  );
                  if (mounted) unawaited(_load());
                },
              )
            else
              _formCard(),
          ],
        ),
      );
    }

    return AppPageScaffold(
      appBar: AppBar(
        title: const AppText(
          'Withdrawal Request',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: body,
    );
  }


}
