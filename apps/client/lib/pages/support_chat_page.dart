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
      duration: const Duration(milliseconds: 360),
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
          top: false,
          bottom: false,
          child: Column(
            children: [
              _buildHeader(),
              if (_noticeVisible) _buildNotice(),
              Expanded(
                child: FadeTransition(
                  opacity: CurvedAnimation(
                    parent: _intro,
                    curve: Curves.easeOut,
                  ),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                    children: [
                      const Center(child: _DayChip()),
                      const SizedBox(height: 12),
                      _AgentBubble(
                        text: bubbleText,
                        isError: _error != null,
                        isConnecting: _opening,
                      ),
                      const SizedBox(height: 14),
                      AppText(
                        'Quick topics',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.25,
                          color: Colors.blueGrey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
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

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppConfig.primaryDarkColor, AppConfig.primaryColor],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: Color(0x28165DFF),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: () => Navigator.pop(context),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 34, height: 34),
              style: IconButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.white.withValues(alpha: 0.12),
              ),
              icon: const Icon(Icons.close_rounded, size: 18),
              tooltip: 'Close',
            ),
            const SizedBox(width: 6),
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.support_agent_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: _opening
                          ? const Color(0xFFFBBF24)
                          : const Color(0xFF22C55E),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppText(
                    'Online Customer Service',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 1),
                  AppText(
                    _opening
                        ? 'Connecting…'
                        : (_nativeChatAvailable
                            ? 'Online now'
                            : 'In-app support'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xCCDDE8FF),
                    ),
                  ),
                ],
              ),
            ),
            if (_opening)
              const Padding(
                padding: EdgeInsets.only(right: 6),
                child: SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
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
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 2),
      child: Material(
        color: const Color(0xFFDCE9FF),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 2, 6),
          child: Row(
            children: [
              const Icon(
                Icons.verified_user_outlined,
                size: 15,
                color: AppConfig.primaryColor,
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: AppText(
                  'Dedicated help for deposits, account security and trading.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10, color: Color(0xFF35558A)),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(width: 28, height: 28),
                onPressed: () => setState(() => _noticeVisible = false),
                icon: const Icon(
                  Icons.close_rounded,
                  size: 14,
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
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F3)),
                boxShadow: const [
                  BoxShadow(color: Color(0x10000000), blurRadius: 8),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    color: Colors.blueGrey.shade300,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: TextField(
                      enabled: false,
                      style: const TextStyle(fontSize: 12),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: _opening
                            ? 'Connecting…'
                            : (_nativeChatAvailable
                                ? 'Message opens in live chat'
                                : 'Use a topic or open on mobile'),
                        hintStyle: TextStyle(
                          color: Colors.blueGrey.shade400,
                          fontSize: 12,
                        ),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: _opening
                ? AppConfig.primaryColor.withValues(alpha: 0.55)
                : AppConfig.primaryColor,
            shape: const CircleBorder(),
            elevation: 1.5,
            shadowColor: const Color(0x33165DFF),
            child: InkWell(
              onTap: _opening ? null : () => _open(),
              customBorder: const CircleBorder(),
              child: SizedBox(
                width: 40,
                height: 40,
                child: Icon(
                  _nativeChatAvailable
                      ? Icons.send_rounded
                      : Icons.refresh_rounded,
                  color: Colors.white,
                  size: 18,
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFE7EDF8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const AppText(
        'TODAY',
        style: TextStyle(
          fontSize: 9,
          letterSpacing: 1,
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
        constraints: const BoxConstraints(maxWidth: 280),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: isError ? const Color(0xFFFFF1F2) : Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(5),
              topRight: Radius.circular(14),
              bottomLeft: Radius.circular(14),
              bottomRight: Radius.circular(14),
            ),
            border: Border.all(
              color: isError
                  ? const Color(0xFFFECACA)
                  : const Color(0xFFE2E8F3),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A0B1F44),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isConnecting)
                const Padding(
                  padding: EdgeInsets.only(bottom: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 11,
                        height: 11,
                        child: CircularProgressIndicator(strokeWidth: 1.6),
                      ),
                      SizedBox(width: 6),
                      AppText(
                        'Connecting',
                        style: TextStyle(
                          fontSize: 10,
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
                  height: 1.4,
                  fontSize: 13,
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
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFD8E2F1)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: AppConfig.primaryColor),
              const SizedBox(width: 5),
              AppText(
                label,
                style: const TextStyle(
                  fontSize: 11,
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
