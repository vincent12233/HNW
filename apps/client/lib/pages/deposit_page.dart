import 'dart:async';

import 'package:flutter/material.dart';
import '../app_config.dart';
import '../l10n/app_language.dart';
import '../models/deposit_request.dart';
import '../services/app_content_service.dart';
import '../services/trading_service.dart';
import '../theme/app_motion.dart';
import '../theme/app_spacing.dart';
import '../utils/client_error_message.dart';
import '../utils/number_formatters.dart';
import '../widgets/app_feedback.dart';
import '../widgets/app_page_scaffold.dart';
import '../widgets/support_chat_launcher.dart';

class DepositPage extends StatefulWidget {
  const DepositPage({super.key, this.tradingService});

  final TradingService? tradingService;

  @override
  State<DepositPage> createState() => _DepositPageState();
}

class _DepositPageState extends State<DepositPage> {
  late final _service = widget.tradingService ?? TradingService();
  final _appContent = AppContentService.instance;
  List<DepositRequest> _history = const [];
  bool _loading = true;
  String? _error;
  int _generation = 0;
  Future<void>? _inFlight;

  @override
  void initState() {
    super.initState();
    _appContent.addListener(_onContentChanged);
    unawaited(_appContent.load());
    unawaited(_load());
  }

  @override
  void dispose() {
    _generation++;
    _appContent.removeListener(_onContentChanged);
    super.dispose();
  }

  void _onContentChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _load() {
    final pending = _inFlight;
    if (pending != null) return pending;
    final request = ++_generation;
    final future = _loadOnce(request);
    _inFlight = future;
    return future.whenComplete(() {
      if (identical(_inFlight, future)) {
        _inFlight = null;
      }
    });
  }

  Future<void> _loadOnce(int request) async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final rows = await _service.fetchMyDeposits();
      if (!mounted || request != _generation) return;
      setState(() {
        _history = rows;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted || request != _generation) return;
      setState(() {
        _loading = false;
        _error = clientErrorMessage(
          error,
          fallback: 'Unable to load deposit history. Please try again.',
        );
      });
    }
  }

  void _contact() {
    final content = _appContent.current;
    final message = content.text(
      'deposit',
      'chat_preset',
      fallback: content.text(
        'support',
        'chat_preset.deposit',
        fallback: 'Hello, I would like to make a deposit.',
      ),
    );
    unawaited(showSupportChatPanel(context, initialMessage: message));
  }

  @override
  Widget build(BuildContext context) {
    final content = _appContent.current;
    final heroTitle = content.text(
      'deposit',
      'hero_title',
      fallback: 'Fund your trading account',
    );
    final instructions = content.text(
      'deposit',
      'instructions',
      fallback:
          'Contact support for payment details. After you pay, finance credits your account. Deposits are not submitted inside the app.',
    );
    final ctaLabel = content.text(
      'deposit',
      'cta_label',
      fallback: 'Contact customer support',
    );
    final historyEmpty = content.text(
      'deposit',
      'history_empty',
      fallback: 'No deposit records yet.',
    );
    final terms = content.text(
      'deposit',
      'terms',
      fallback:
          '• Verify the beneficiary details with Online Customer Service before transferring.\n\n• Deposits are credited only after finance confirmation.\n\n• Keep your transfer receipt for settlement support.',
    );

    return Scaffold(
      appBar: AppBar(
        title: AppText(
          content.text('deposit', 'page_title', fallback: 'Deposit'),
        ),
        leading: const BackButton(),
      ),
      body: RefreshIndicator(
        onRefresh: _loading ? () async {} : _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 24),
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppConfig.primaryDarkColor, AppConfig.primaryColor],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33165DFF),
                    blurRadius: 16,
                    offset: Offset(0, 7),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .16),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AppText(
                          heroTitle,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  AppText(
                    instructions,
                    style: const TextStyle(
                      height: 1.4,
                      color: Color(0xDDE8F0FF),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: AppMotion.tapTarget,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppConfig.primaryColor,
                      ),
                      onPressed: _contact,
                      child: AppText(ctaLabel),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: AppText(
                            content.text(
                              'deposit',
                              'history_section_title',
                              fallback: 'DEPOSIT HISTORY',
                            ),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              letterSpacing: .5,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Refresh deposit history',
                          onPressed: _loading ? null : () => unawaited(_load()),
                          icon: const Icon(Icons.refresh_rounded),
                        ),
                      ],
                    ),
                    ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 120),
                      child: _historyBody(historyEmpty: historyEmpty),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      content.text(
                        'deposit',
                        'terms_section_title',
                        fallback: 'TERMS',
                      ),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        letterSpacing: .8,
                        color: AppConfig.primaryDarkColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    AppText(
                      terms,
                      style: const TextStyle(
                        height: 1.45,
                        color: Color(0xFF52627A),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _historyBody({required String historyEmpty}) {
    if (_loading && _history.isEmpty && _error == null) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: AppLoadingView(message: 'Loading deposit history'),
      );
    }
    if (_error != null && _history.isEmpty) {
      return AppErrorView(
        title: 'Unable to load deposit history',
        message: _error,
        onRetry: _loading ? null : () => unawaited(_load()),
      );
    }
    if (_history.isEmpty) {
      return AppEmptyState(
        title: historyEmpty,
        message:
            'Credited deposits appear here after finance confirms your payment.',
        icon: Icons.receipt_long_outlined,
      );
    }
    return Column(
      children: [
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: AppText(
              _error!,
              style: const TextStyle(color: Color(0xFFB45309), height: 1.4),
            ),
          ),
        ..._history.map(
          (entry) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              Icons.south_west_rounded,
              color: AppConfig.primaryColor,
            ),
            title: AppText(formatPrice(entry.amount)),
            subtitle: AppText('${entry.createdAt.toLocal()} · ${entry.status}'),
            trailing: entry.note == null ? null : AppText(entry.note!),
          ),
        ),
      ],
    );
  }
}
