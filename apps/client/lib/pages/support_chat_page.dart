import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app_config.dart';
import '../l10n/app_language.dart';
import '../services/app_content_service.dart';
import '../services/auth_service.dart';
import '../services/salesmartly_service.dart';

class SupportChatPage extends StatefulWidget {
  const SupportChatPage({super.key, this.initialMessage});

  final String? initialMessage;

  @override
  State<SupportChatPage> createState() => _SupportChatPageState();
}

class _SupportChatPageState extends State<SupportChatPage>
    with SingleTickerProviderStateMixin {
  final _saleSmartly = SaleSmartlyService();
  final _appContent = AppContentService.instance;
  late final AnimationController _intro;

  String? _error;
  bool _opening = false;
  bool _noticeVisible = true;
  String? _selectedMessage;

  bool get _nativeChatAvailable =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();
    _selectedMessage = widget.initialMessage;
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    )..forward();
    _appContent.addListener(_onContentChanged);
    unawaited(_appContent.load());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_nativeChatAvailable) {
        unawaited(_open());
      }
    });
  }

  @override
  void dispose() {
    _appContent.removeListener(_onContentChanged);
    _intro.dispose();
    super.dispose();
  }

  void _onContentChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _open({String? message}) async {
    if (_opening) return;
    if (message != null) {
      _selectedMessage = message;
    }
    final launchMessage = _selectedMessage?.trim();

    if (!_nativeChatAvailable) {
      return;
    }

    setState(() {
      _opening = true;
      _error = null;
    });

    try {
      final session = await AuthService().restoreSession();
      if (session == null) {
        throw const SaleSmartlyException('Please sign in again.');
      }
      final content = await _appContent.load();
      final scriptUrl = content.text('support', 'salesmartly_script_url');
      await _saleSmartly.openChat(
        session: session,
        initialMessage: launchMessage,
        scriptUrlOverride: scriptUrl.isEmpty ? null : scriptUrl,
      );
    } on SaleSmartlyException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  String _preset(String key, String fallback) {
    return _appContent.current.text('support', key, fallback: fallback);
  }

  @override
  Widget build(BuildContext context) {
    final content = _appContent.current;
    final greeting = content.text(
      'support',
      'greeting',
      fallback:
          'Welcome. Our support team can help with deposits, trading and account questions.',
    );
    final hours = content.text(
      'support',
      'hours',
      fallback: 'Support is available during business hours via in-app chat.',
    );

    final bubbleText = _error ??
        (_opening
            ? 'Connecting you to an agent…'
            : (_nativeChatAvailable
                ? greeting
                : '$greeting\n\n$hours'));

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE8F1FF), Color(0xFFF7F9FC), Color(0xFFFCFDFE)],
            stops: [0, 0.35, 1],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(hours),
              if (_noticeVisible) _buildNotice(),
              Expanded(
                child: FadeTransition(
                  opacity: CurvedAnimation(
                    parent: _intro,
                    curve: Curves.easeOut,
                  ),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
                    children: [
                      const Center(child: _DayChip()),
                      const SizedBox(height: 16),
                      _AgentBubble(
                        text: bubbleText,
                        isError: _error != null,
                        isConnecting: _opening,
                      ),
                      const SizedBox(height: 18),
                      AppText(
                        'Quick topics',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                          color: Colors.blueGrey.shade600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _SupportTopic(
                            label: 'Deposit',
                            icon: Icons.account_balance_wallet_outlined,
                            onTap: () => _open(
                              message: _preset(
                                'chat_preset.deposit',
                                'Hello, I would like to add money to my account.',
                              ),
                            ),
                          ),
                          _SupportTopic(
                            label: 'Trading',
                            icon: Icons.candlestick_chart_rounded,
                            onTap: () => _open(
                              message: _preset(
                                'chat_preset.help',
                                'Hello, I need help with a trade.',
                              ),
                            ),
                          ),
                          _SupportTopic(
                            label: 'Account',
                            icon: Icons.shield_outlined,
                            onTap: () => _open(
                              message: _preset(
                                'chat_preset.help',
                                'Hello, I need help with my account.',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              _buildComposer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(String hours) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppConfig.primaryDarkColor, AppConfig.primaryColor],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33165DFF),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: () => Navigator.pop(context),
              style: IconButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.white.withValues(alpha: 0.12),
              ),
              icon: const Icon(Icons.close_rounded),
              tooltip: 'Close',
            ),
            const SizedBox(width: 8),
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.support_agent_rounded,
                    color: Colors.white,
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: _opening
                          ? const Color(0xFFFBBF24)
                          : const Color(0xFF22C55E),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppText(
                    'Online Customer Service',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  AppText(
                    _opening
                        ? 'Connecting…'
                        : (_nativeChatAvailable
                            ? 'Online now'
                            : 'In-app support'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xCCDDE8FF),
                    ),
                  ),
                ],
              ),
            ),
            if (_opening)
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotice() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Material(
        color: const Color(0xFFDCE9FF),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
          child: Row(
            children: [
              const Icon(
                Icons.verified_user_outlined,
                size: 17,
                color: AppConfig.primaryColor,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: AppText(
                  'Dedicated help for deposits, account security and trading.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: Color(0xFF35558A)),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () => setState(() => _noticeVisible = false),
                icon: const Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: Color(0xFF6B86B2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComposer() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
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
                  Icon(
                    Icons.lock_outline_rounded,
                    color: Colors.blueGrey.shade300,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      enabled: false,
                      decoration: InputDecoration(
                        hintText: _opening
                            ? 'Connecting…'
                            : (_nativeChatAvailable
                                ? 'Message opens in live chat'
                                : 'Use a topic or open on mobile'),
                        hintStyle: TextStyle(
                          color: Colors.blueGrey.shade400,
                          fontSize: 13,
                        ),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Material(
            color: _opening
                ? AppConfig.primaryColor.withValues(alpha: 0.55)
                : AppConfig.primaryColor,
            shape: const CircleBorder(),
            elevation: 2,
            shadowColor: const Color(0x33165DFF),
            child: InkWell(
              onTap: _opening ? null : () => _open(),
              customBorder: const CircleBorder(),
              child: SizedBox(
                width: 48,
                height: 48,
                child: Icon(
                  _nativeChatAvailable
                      ? Icons.send_rounded
                      : Icons.refresh_rounded,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
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
    );
  }
}

class _AgentBubble extends StatelessWidget {
  const _AgentBubble({
    required this.text,
    required this.isError,
    required this.isConnecting,
  });

  final String text;
  final bool isError;
  final bool isConnecting;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: isError ? const Color(0xFFFFF1F2) : Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(6),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(18),
            ),
            border: Border.all(
              color: isError
                  ? const Color(0xFFFECACA)
                  : const Color(0xFFE2E8F3),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0D0B1F44),
                blurRadius: 14,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isConnecting)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 1.8),
                      ),
                      SizedBox(width: 8),
                      AppText(
                        'Connecting',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppConfig.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              AppText(
                text,
                style: TextStyle(
                  height: 1.45,
                  color: isError
                      ? const Color(0xFF9F1239)
                      : const Color(0xFF344054),
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
  const _SupportTopic({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
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
        ),
      ),
    );
  }
}
