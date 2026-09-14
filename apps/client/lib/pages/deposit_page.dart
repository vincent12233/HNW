import 'dart:async';

import 'package:flutter/material.dart';
import '../app_config.dart';
import '../l10n/app_language.dart';
import '../models/account_transaction.dart';
import '../services/app_content_service.dart';
import '../services/trading_service.dart';
import 'support_chat_page.dart';
import '../utils/number_formatters.dart';

class DepositPage extends StatefulWidget {
  const DepositPage({super.key});
  @override
  State<DepositPage> createState() => _DepositPageState();
}

class _DepositPageState extends State<DepositPage> {
  final _service = TradingService();
  final _appContent = AppContentService.instance;
  List<AccountTransaction> _history = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _appContent.addListener(_onContentChanged);
    unawaited(_appContent.load());
    _load();
  }

  @override
  void dispose() {
    _appContent.removeListener(_onContentChanged);
    super.dispose();
  }

  void _onContentChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    try {
      final all = await _service.fetchTransactions();
      if (!mounted) return;
      setState(() {
        _history = all
            .where((e) => e.type.toUpperCase().contains('DEPOSIT'))
            .toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
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
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SupportChatPage(initialMessage: message),
      ),
    );
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
          'Contact customer support to complete your deposit operation.',
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
          content.text(
            'deposit',
            'page_title',
            fallback: 'Deposit',
          ),
        ),
        leading: const BackButton(),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
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
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        AppText(
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
                        IconButton(
                          onPressed: _loading ? null : _load,
                          icon: const Icon(Icons.refresh_rounded),
                        ),
                      ],
                    ),
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_history.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: AppText(historyEmpty),
                      )
                    else
                      ..._history.map(
                        (entry) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: Icon(
                              entry.amount >= 0
                                  ? Icons.arrow_downward_rounded
                                  : Icons.arrow_upward_rounded,
                              color: entry.amount >= 0
                                  ? AppConfig.gainColor
                                  : AppConfig.lossColor,
                            ),
                            title: AppText(formatPrice(entry.amount)),
                            subtitle: AppText(
                              '${entry.createdAt.toLocal()} · ${entry.status}',
                            ),
                            trailing: entry.note == null
                                ? null
                                : AppText(entry.note!),
                          ),
                        ),
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
}
