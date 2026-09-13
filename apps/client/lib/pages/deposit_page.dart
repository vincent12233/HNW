import 'package:flutter/material.dart';
import '../app_config.dart';
import '../l10n/app_language.dart';
import '../models/account_transaction.dart';
import '../services/trading_service.dart';
import 'support_chat_page.dart';
import '../utils/number_formatters.dart';

class DepositPage extends StatefulWidget {
  const DepositPage({super.key});
  @override State<DepositPage> createState() => _DepositPageState();
}

class _DepositPageState extends State<DepositPage> {
  final _service = TradingService();
  List<AccountTransaction> _history = const [];
  bool _loading = true;

  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try {
      final all = await _service.fetchTransactions();
      if (!mounted) return;
      setState(() { _history = all.where((e) => e.type.toUpperCase().contains('DEPOSIT')).toList(); _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }
  void _contact() => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SupportChatPage(initialMessage: 'Hello, I would like to make a deposit.')));

  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const AppText('Deposit'), leading: const BackButton()),
    body: RefreshIndicator(onRefresh: _load, child: ListView(padding: const EdgeInsets.fromLTRB(12, 14, 12, 24), children: [
      Card(child: Padding(padding: const EdgeInsets.fromLTRB(18, 18, 18, 20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const AppText('Contact customer support to complete your deposit operation.', style: TextStyle(height: 1.4, color: Color(0xFF52627A))),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity, child: FilledButton(onPressed: _contact, child: const AppText('Contact customer support'))),
      ]))),
      const SizedBox(height: 18),
      Card(child: Padding(padding: const EdgeInsets.fromLTRB(18, 16, 18, 18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const AppText('DEPOSIT HISTORY', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: .5)), IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded))]),
      if (_loading) const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
      else if (_history.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: AppText('No deposit records yet.'))
      else ..._history.map((entry) => Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(leading: Icon(entry.amount >= 0 ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded, color: entry.amount >= 0 ? AppConfig.gainColor : AppConfig.lossColor), title: AppText(formatPrice(entry.amount)), subtitle: AppText('${entry.createdAt.toLocal()} · ${entry.status}'), trailing: entry.note == null ? null : AppText(entry.note!)))),
      ]))),
      const SizedBox(height: 16),
      const Card(child: Padding(padding: EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AppText('TERMS', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: .5)),
        SizedBox(height: 12), AppText('Contact customer support to verify the deposit instructions before transferring funds. Deposits appear after finance confirmation.', style: TextStyle(height: 1.45, color: Color(0xFF52627A))),
      ]))),
    ])),
  );
}
