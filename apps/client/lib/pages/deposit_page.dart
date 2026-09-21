import 'dart:async';

import 'package:flutter/material.dart';
import '../l10n/app_language.dart';
import '../models/deposit_request.dart';
import '../services/app_content_service.dart';
import '../services/trading_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/client_error_message.dart';
import '../utils/number_formatters.dart';
import '../widgets/app_buttons.dart';
import '../widgets/app_card.dart';
import '../widgets/app_feedback.dart';
import '../widgets/app_page_scaffold.dart';
import '../widgets/app_status_label.dart';
import '../widgets/record_detail_sheet.dart';
import '../widgets/support_chat_launcher.dart';

const _depositStatusLabels = {
  'PENDING': 'Pending',
  'APPROVED': 'Approved',
  'REJECTED': 'Rejected',
};

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

    return AppPageScaffold(
      appBar: AppBar(
        title: AppText(
          content.text('deposit', 'page_title', fallback: 'Deposit'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        leading: const BackButton(),
      ),
      body: RefreshIndicator(
        onRefresh: _loading ? () async {} : _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: AppSpacing.page,
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(heroTitle, style: AppTypography.titleLarge),
                  const SizedBox(height: AppSpacing.sm),
                  AppText(
                    instructions,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppPrimaryButton(label: ctaLabel, onPressed: _contact),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppCard(
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
                          style: AppTypography.labelLarge.copyWith(
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
            const SizedBox(height: AppSpacing.lg),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(
                    content.text(
                      'deposit',
                      'terms_section_title',
                      fallback: 'TERMS',
                    ),
                    style: AppTypography.labelLarge.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: .8,
                      color: AppColors.brandDark,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppText(
                    terms,
                    style: AppTypography.bodyMedium.copyWith(
                      height: 1.45,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _historyBody({required String historyEmpty}) {
    if (_loading && _history.isEmpty && _error == null) {
      return const AppLoadingView(
        compact: true,
        message: 'Loading deposit history',
      );
    }
    if (_error != null && _history.isEmpty) {
      return AppErrorView(
        compact: true,
        title: 'Unable to load deposit history',
        message: _error,
        onRetry: () => unawaited(_load()),
      );
    }
    if (_history.isEmpty) {
      return AppEmptyState(
        compact: true,
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
        ..._history.map((entry) {
          final status = displayStatusLabel(
            entry.status,
            labels: _depositStatusLabels,
          );
          return Material(
            color: Colors.transparent,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              onTap: () => unawaited(
                showRecordDetailSheet(
                  context,
                  title: 'Deposit request',
                  status: AppLabeledStatus(
                    status: entry.status,
                    labels: _depositStatusLabels,
                  ),
                  rows: [
                    ('Amount', formatPrice(entry.amount)),
                    ('Status', status),
                    ('Requested', formatAppDateTime(entry.createdAt)),
                    ('Payment method', entry.paymentMethod ?? 'Unavailable'),
                    ('Reference', entry.referenceId ?? 'Unavailable'),
                    ('Note', entry.note ?? 'Unavailable'),
                  ],
                ),
              ),
              leading: Icon(
                Icons.south_west_rounded,
                color: AppColors.brandPrimary,
              ),
              title: AppText(formatPrice(entry.amount)),
              subtitle: AppText(
                '${formatAppDateTime(entry.createdAt)} · $status',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 96),
                child: AppLabeledStatus(
                  status: entry.status,
                  labels: _depositStatusLabels,
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}
