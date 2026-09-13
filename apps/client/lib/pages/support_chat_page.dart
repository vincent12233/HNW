import '../l10n/app_language.dart';
import 'package:flutter/material.dart';

import '../app_config.dart';
import '../services/auth_service.dart';
import '../services/salesmartly_service.dart';

class SupportChatPage extends StatefulWidget {
  const SupportChatPage({super.key, this.initialMessage});

  final String? initialMessage;

  @override
  State<SupportChatPage> createState() => _SupportChatPageState();
}

class _SupportChatPageState extends State<SupportChatPage> {
  final _saleSmartly = SaleSmartlyService();
  String? _error;
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  Future<void> _open() async {
    if (_opening) return;
    setState(() {
      _opening = true;
      _error = null;
    });

    try {
      final session = await AuthService().restoreSession();
      if (session == null) {
        throw const SaleSmartlyException('Please sign in again.');
      }
      await _saleSmartly.openChat(
        session: session,
        initialMessage: widget.initialMessage,
      );
    } on SaleSmartlyException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FF),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(children: [
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
                Expanded(child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), boxShadow: const [BoxShadow(color: Color(0x16000000), blurRadius: 10)]),
                  child: Row(children: [
                    const CircleAvatar(radius: 20, backgroundColor: AppConfig.primaryColor, child: Icon(Icons.support_agent_rounded, color: Colors.white)),
                    const SizedBox(width: 10),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const AppText('Online Customer Service', style: TextStyle(fontWeight: FontWeight.w700)),
                      AppText(_opening ? 'Connecting…' : 'We are here to help', style: const TextStyle(fontSize: 11, color: Colors.black54)),
                    ]),
                  ]),
                )),
              ]),
            ),
            Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(20, 18, 20, 20), children: [
              Center(child: AppText('Today', style: const TextStyle(fontSize: 11, color: Colors.black45))),
              const SizedBox(height: 18),
              Align(alignment: Alignment.centerLeft, child: Container(
                constraints: const BoxConstraints(maxWidth: 290),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
                child: AppText(_error ?? (_opening ? 'Welcome. Connecting you to customer service…' : 'Welcome to customer service. How can we help?'), style: const TextStyle(height: 1.35)),
              )),
            ])),
            Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 14), child: Row(children: [
              Expanded(child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), boxShadow: const [BoxShadow(color: Color(0x12000000), blurRadius: 8)]),
                child: Row(children: [
                  const Icon(Icons.add_rounded, color: Colors.black45),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(enabled: false, decoration: InputDecoration(hintText: _opening ? 'Connecting…' : 'Type a message…', border: InputBorder.none))),
                  const Icon(Icons.sentiment_satisfied_alt_outlined, color: Colors.black45),
                ]),
              )),
              const SizedBox(width: 10),
              Material(color: AppConfig.primaryColor, shape: const CircleBorder(), child: InkWell(onTap: _opening ? null : _open, customBorder: const CircleBorder(), child: const SizedBox(width: 48, height: 48, child: Icon(Icons.send_rounded, color: Colors.white)))),
            ]),
          ],
        ),
      ),
    );
  }
}
