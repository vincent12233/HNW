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
    appBar: AppBar(title: const AppText('Deposit')),
    body: RefreshIndicator(onRefresh: _load, child: ListView(padding: const EdgeInsets.all(16), children: [
      Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const AppText('Institutional Deposit Compliance Notice', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        const SizedBox(height: 10),
        const AppText('All institutional trading deposits must complete fund verification through the designated verification account before being credited to your account.', style: TextStyle(height: 1.4)),
        const SizedBox(height: 14),
        const AppText('Deposit Instructions', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        const AppText('Contact Online Customer Support through the application to obtain the designated fund verification account details. Transfer funds only to official account details.', style: TextStyle(height: 1.4)),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _contact, icon: const Icon(Icons.support_agent_rounded), label: const AppText('Contact customer support'))),
      ]))),
      const SizedBox(height: 16),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const AppText('DEPOSIT HISTORY', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: .5)), IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded))]),
      if (_loading) const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
      else if (_history.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: AppText('No deposit records yet.'))
      else ..._history.map((entry) => Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(leading: Icon(entry.amount >= 0 ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded, color: entry.amount >= 0 ? AppConfig.gainColor : AppConfig.lossColor), title: AppText(formatPrice(entry.amount)), subtitle: AppText('${entry.createdAt.toLocal()} · ${entry.status}'), trailing: entry.note == null ? null : AppText(entry.note!)))),
      const SizedBox(height: 16),
      const Card(child: Padding(padding: EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AppText('Deposit Terms and Conditions', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        SizedBox(height: 12), AppText('Deposits are subject to minimum amount requirements, processing confirmation and compliance review. High-value deposits may require proof of payment. Please verify all account details through official customer support before transferring funds.', style: TextStyle(height: 1.45)),
      ]))),
    ])),
  );
}
