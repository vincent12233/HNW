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
      appBar: AppBar(title: const Text('Online Customer Service')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.support_agent_rounded,
                size: 58,
                color: AppConfig.primaryColor,
              ),
              const SizedBox(height: 18),
              Text(
                _error ??
                    (_opening
                        ? 'Opening secure customer service…'
                        : 'Customer service closed. You can open it again.'),
                textAlign: TextAlign.center,
                style: const TextStyle(height: 1.45),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _opening ? null : _open,
                icon: _opening
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.chat_bubble_outline_rounded),
                label: Text(_error == null ? 'Open Chat' : 'Try Again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
