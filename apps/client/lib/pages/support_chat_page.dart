import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app_config.dart';
import '../l10n/app_language.dart';
import '../services/app_content_service.dart';
import '../services/auth_service.dart';
import '../services/salesmartly_service.dart';
import '../widgets/scrolling_notice_text.dart';
import '../widgets/support_ui_metrics.dart';

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
    final m = SupportUiMetrics.of(context);
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
      fallback:
          'Online customer service hours: Mon–Sun 09:00–22:00 (IST). We are here to help with deposits, trading and account questions.',
    );

    final bubbleText = _error ??
        (_opening
            ? 'Connecting you to an agent…'
            : (_nativeChatAvailable
                ? greeting
                : '$greeting\n\n$hours'));

    // Always show the CMS hours notice unless the user dismisses it.
    final showNotice = _noticeVisible && hours.trim().isNotEmpty;

    return Material(
      color: AppConfig.backgroundColor,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppConfig.primarySoftColor, Color(0xFFF7F9FC), Color(0xFFFCFDFE)],
            stops: [0, 0.4, 1],
          ),
        ),
        child: FadeTransition(
          opacity: CurvedAnimation(parent: _intro, curve: Curves.easeOut),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final body = Padding(
                padding: EdgeInsets.fromLTRB(
                  m.contentPadding,
                  m.contentPadding * 0.65,
                  m.contentPadding,
                  m.contentPadding * 0.45,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Center(child: _DayChip()),
                    SizedBox(height: 8 * m.scale),
                    _AgentBubble(
                      text: bubbleText,
                      isError: _error != null,
                      isConnecting: _opening,
                      metrics: m,
                    ),
                    SizedBox(height: 10 * m.scale),
                    AppText(
                      'Quick topics',
                      style: TextStyle(
                        fontSize: m.subtitleSize,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.25,
                        color: Colors.blueGrey.shade600,
                      ),
                    ),
                    SizedBox(height: 6 * m.scale),
                    Wrap(
                      spacing: 6 * m.scale,
                      runSpacing: 6 * m.scale,
                      children: [
                        _SupportTopic(
                          label: 'Deposit',
                          icon: Icons.account_balance_wallet_outlined,
                          metrics: m,
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
                          metrics: m,
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
                          metrics: m,
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
              );

              final columnChildren = <Widget>[
                _buildHeader(m),
                if (showNotice) _buildNotice(m, hours.trim()),
                Expanded(child: SingleChildScrollView(child: body)),
                _buildComposer(m),
              ];

              return SizedBox.expand(
                child: Column(
                  children: columnChildren,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(SupportUiMetrics m) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        m.headerPadding,
        m.headerPadding,
        m.headerPadding,
        m.headerPadding * 0.75,
      ),
      child: Container(
        padding: EdgeInsets.all(m.headerPadding * 0.75),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppConfig.primaryDarkColor, AppConfig.primaryColor],
          ),
          borderRadius: BorderRadius.circular(m.panelRadius * 0.85),
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
              constraints: BoxConstraints.tightFor(
                width: m.avatarSize + 2,
                height: m.avatarSize + 2,
              ),
              style: IconButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.white.withValues(alpha: 0.12),
              ),
              icon: Icon(Icons.close_rounded, size: 16 * m.scale),
              tooltip: 'Close',
            ),
            SizedBox(width: 6 * m.scale),
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: m.avatarSize,
                  height: m.avatarSize,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.support_agent_rounded,
                    color: Colors.white,
                    size: m.avatarSize * 0.55,
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 9 * m.scale,
                    height: 9 * m.scale,
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
            SizedBox(width: 8 * m.scale),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(
                    'Online Customer Service',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      fontSize: m.titleSize,
                    ),
                  ),
                  SizedBox(height: 1 * m.scale),
                  AppText(
                    _opening
                        ? 'Connecting…'
                        : (_nativeChatAvailable
                            ? 'Online now'
                            : 'In-app support'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: m.subtitleSize,
                      color: const Color(0xCCDDE8FF),
                    ),
                  ),
                ],
              ),
            ),
            if (_opening)
              Padding(
                padding: EdgeInsets.only(right: 6 * m.scale),
                child: SizedBox(
                  width: 14 * m.scale,
                  height: 14 * m.scale,
                  child: const CircularProgressIndicator(
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

  Widget _buildNotice(SupportUiMetrics m, String hoursNotice) {
    final noticeStyle = TextStyle(
      fontSize: m.subtitleSize,
      color: const Color(0xFF35558A),
      height: 1.2,
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(
        m.contentPadding,
        0,
        m.contentPadding,
        2 * m.scale,
      ),
      child: Material(
        color: AppConfig.primarySoftColor,
        borderRadius: BorderRadius.circular(10 * m.scale),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            m.contentPadding * 0.85,
            6 * m.scale,
            2,
            6 * m.scale,
          ),
          child: Row(
            children: [
              Icon(
                Icons.schedule_rounded,
                size: 15 * m.scale,
                color: AppConfig.primaryColor,
              ),
              SizedBox(width: 6 * m.scale),
              Expanded(
                child: ScrollingNoticeText(
                  text: hoursNotice,
                  style: noticeStyle,
                  height: (m.subtitleSize * 1.35).clamp(16.0, 22.0),
                  pixelsPerSecond: 34,
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: BoxConstraints.tightFor(
                  width: 28 * m.scale,
                  height: 28 * m.scale,
                ),
                onPressed: () => setState(() => _noticeVisible = false),
                icon: Icon(
                  Icons.close_rounded,
                  size: 14 * m.scale,
                  color: const Color(0xFF6B86B2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComposer(SupportUiMetrics m) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        m.contentPadding,
        4 * m.scale,
        m.contentPadding,
        m.contentPadding * 0.85,
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              constraints: BoxConstraints(minHeight: m.composerHeight),
              padding: EdgeInsets.symmetric(
                horizontal: m.contentPadding,
                vertical: 2 * m.scale,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14 * m.scale),
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
                    size: 16 * m.scale,
                  ),
                  SizedBox(width: 6 * m.scale),
                  Expanded(
                    child: TextField(
                      enabled: false,
                      style: TextStyle(fontSize: m.bodySize - 1),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: _opening
                            ? 'Connecting…'
                            : (_nativeChatAvailable
                                ? 'Message opens in live chat'
                                : 'Use a topic or open on mobile'),
                        hintStyle: TextStyle(
                          color: Colors.blueGrey.shade400,
                          fontSize: m.bodySize - 1,
                        ),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: 8 * m.scale),
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
                width: m.sendButtonSize,
                height: m.sendButtonSize,
                child: Icon(
                  _nativeChatAvailable
                      ? Icons.send_rounded
                      : Icons.refresh_rounded,
                  color: Colors.white,
                  size: 18 * m.scale,
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
    final m = SupportUiMetrics.of(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 10 * m.scale,
        vertical: 4 * m.scale,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFE7EDF8),
        borderRadius: BorderRadius.circular(16 * m.scale),
      ),
      child: AppText(
        'TODAY',
        style: TextStyle(
          fontSize: (9 * m.scale).clamp(8.0, 11.0),
          letterSpacing: 1,
          fontWeight: FontWeight.w800,
          color: const Color(0xFF667085),
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
    required this.metrics,
  });

  final String text;
  final bool isError;
  final bool isConnecting;
  final SupportUiMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final m = metrics;
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: math.min(
            280 * m.scale,
            MediaQuery.sizeOf(context).width * 0.72,
          ),
        ),
        child: Container(
          padding: EdgeInsets.fromLTRB(
            m.contentPadding,
            m.contentPadding * 0.85,
            m.contentPadding,
            m.contentPadding * 0.85,
          ),
          decoration: BoxDecoration(
            color: isError ? const Color(0xFFFFF1F2) : Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(5 * m.scale),
              topRight: Radius.circular(14 * m.scale),
              bottomLeft: Radius.circular(14 * m.scale),
              bottomRight: Radius.circular(14 * m.scale),
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
                Padding(
                  padding: EdgeInsets.only(bottom: 6 * m.scale),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 11 * m.scale,
                        height: 11 * m.scale,
                        child: const CircularProgressIndicator(strokeWidth: 1.6),
                      ),
                      SizedBox(width: 6 * m.scale),
                      AppText(
                        'Connecting',
                        style: TextStyle(
                          fontSize: m.subtitleSize,
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
                  fontSize: m.bodySize,
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
    required this.metrics,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final SupportUiMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final m = metrics;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16 * m.scale),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16 * m.scale),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: 10 * m.scale,
            vertical: 7 * m.scale,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16 * m.scale),
            border: Border.all(color: const Color(0xFFD8E2F1)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14 * m.scale, color: AppConfig.primaryColor),
              SizedBox(width: 5 * m.scale),
              AppText(
                label,
                style: TextStyle(
                  fontSize: m.chipFontSize,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF344054),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
