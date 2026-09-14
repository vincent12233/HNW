import '../l10n/app_language.dart';
import 'package:flutter/material.dart';

import '../app_config.dart';
import '../services/app_content_service.dart';
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
      final content = await AppContentService.instance.load();
      final scriptUrl = content.text('support', 'salesmartly_script_url');
      await _saleSmartly.openChat(
        session: session,
        initialMessage: widget.initialMessage,
        scriptUrlOverride: scriptUrl.isEmpty ? null : scriptUrl,
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE7F0FF), Color(0xFFF8FAFE)],
          ),
        ),
        child: SafeArea(
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
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                const CircleAvatar(
                                  radius: 20,
                                  backgroundColor: Colors.white,
                                  child: Icon(
                                    Icons.support_agent_rounded,
                                    color: AppConfig.primaryColor,
                                  ),
                                ),
                                Positioned(
                                  right: -1,
                                  bottom: -1,
                                  child: Container(
                                    width: 11,
                                    height: 11,
                                    decoration: BoxDecoration(
                                      color: Color(0xFF22C55E),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
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
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCE9FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFC6D9FF)),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.notifications_active_rounded,
                      size: 17,
                      color: AppConfig.primaryColor,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: AppText(
                        'Dedicated support for deposits, account security and trading services.',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF35558A),
                        ),
                      ),
                    ),
                    Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: Color(0xFF6B86B2),
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
                child: Column(
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _SupportTopic(
                            label: 'Deposit',
                            icon: Icons.account_balance_wallet_outlined,
                          ),
                          SizedBox(width: 8),
                          _SupportTopic(
                            label: 'Trading',
                            icon: Icons.candlestick_chart_rounded,
                          ),
                          SizedBox(width: 8),
                          _SupportTopic(
                            label: 'Account',
                            icon: Icons.shield_outlined,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
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
                              border: Border.all(
                                color: const Color(0xFFE2E8F3),
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x12000000),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.add_rounded,
                                  color: Colors.black45,
                                ),
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
                              child: Icon(
                                Icons.send_rounded,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SupportTopic extends StatelessWidget {
  const _SupportTopic({required this.label, required this.icon});
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFD8E2F1)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppConfig.primaryColor),
        const SizedBox(width: 6),
        AppText(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF344054),
          ),
        ),
      ],
    ),
  );
}
