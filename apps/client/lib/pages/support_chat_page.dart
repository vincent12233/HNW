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
      backgroundColor: const Color(0xFFF3F6FC),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppConfig.primaryDarkColor,
                    ),
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            AppConfig.primaryDarkColor,
                            AppConfig.primaryColor,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x33165DFF),
                            blurRadius: 14,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            radius: 20,
                            backgroundColor: AppConfig.primaryColor,
                            child: Icon(
                              Icons.support_agent_rounded,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const AppText(
                                'Online Customer Service',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                              AppText(
                                _opening
                                    ? 'Connecting…'
                                    : 'We are here to help',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xCCDDE8FF),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                children: [
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE7EDF8),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const AppText(
                        'TODAY',
                        style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 1.1,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF667085),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 290),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 13,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE2E8F3)),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x0D0B1F44),
                            blurRadius: 14,
                            offset: Offset(0, 5),
                          ),
                        ],
                      ),
                      child: AppText(
                        _error ??
                            (_opening
                                ? 'Welcome. Connecting you to customer service…'
                                : 'Welcome to customer service. How can we help?'),
                        style: const TextStyle(
                          height: 1.45,
                          color: Color(0xFF344054),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE2E8F3)),
                        boxShadow: const [
                          BoxShadow(color: Color(0x12000000), blurRadius: 10),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.add_rounded, color: Colors.black45),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              enabled: false,
                              decoration: InputDecoration(
                                hintText: _opening
                                    ? 'Connecting…'
                                    : 'Type a message…',
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.sentiment_satisfied_alt_outlined,
                            color: Colors.black45,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Material(
                    color: AppConfig.primaryColor,
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: _opening ? null : _open,
                      customBorder: const CircleBorder(),
                      child: const SizedBox(
                        width: 48,
                        height: 48,
                        child: Icon(Icons.send_rounded, color: Colors.white),
                      ),
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
}
