import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app_config.dart';
import '../l10n/app_language.dart';
import '../services/app_content_service.dart';
import '../services/auth_service.dart';
import '../services/salesmartly_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../widgets/scrolling_notice_text.dart';
import '../widgets/support_ui_metrics.dart';

part 'support_chat_page_controls.dart';

class SupportChatPage extends StatefulWidget {
  const SupportChatPage({super.key, this.initialMessage});

  final String? initialMessage;

  @override
  State<SupportChatPage> createState() => _SupportChatPageState();
}

class _SupportChatPageState extends State<SupportChatPage>
    with SingleTickerProviderStateMixin {
  void _updateState(VoidCallback update) => setState(update);

  final _saleSmartly = SaleSmartlyService();
  final _appContent = AppContentService.instance;
  late final AnimationController _intro;

  String? _error;
  bool _opening = false;
  bool _noticeVisible = true;
  String? _selectedMessage;

  bool get _chatAvailable =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void initState() {
    super.initState();
    _selectedMessage = widget.initialMessage;
    _intro = AnimationController(
      vsync: this,
      duration: AppMotion.page,
    );
    _appContent.addListener(_onContentChanged);
    unawaited(_appContent.load());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatAvailable) {
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_intro.isDismissed) {
      if (AppMotion.reduce(context)) {
        _intro.value = 1;
      } else {
        _intro.forward();
      }
    }
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

    if (!_chatAvailable) {
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
      final scriptUrl = content
          .text('support', 'salesmartly_script_url')
          .trim();
      await _saleSmartly.openChat(
        session: session,
        initialMessage: launchMessage,
        // CMS (or API env fallback embedded in CMS bundle) first; dart-define last.
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

    final bubbleText =
        _error ??
        (_opening
            ? 'Opening the external customer chat…'
            : (_chatAvailable
                ? '$greeting\n\nThis screen opens an external customer chat. It does not mean an agent is already connected.'
                : '$greeting\n\n$hours'));

    // Always show the CMS hours notice unless the user dismisses it.
    final showNotice = _noticeVisible && hours.trim().isNotEmpty;

    return Material(
      color: AppColors.background,
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
                    if (_error != null) ...[
                      SizedBox(height: 8 * m.scale),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: _opening ? null : () => _open(),
                          icon: const Icon(Icons.refresh),
                          label: const AppText('Retry'),
                        ),
                      ),
                    ],
                    SizedBox(height: 10 * m.scale),
                    AppText(
                      content.text(
                        'support',
                        'quick_topics_label',
                        fallback: 'Quick topics',
                      ),
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
                          label: content.text(
                            'support',
                            'topic.deposit',
                            fallback: 'Deposit',
                          ),
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
                          label: content.text(
                            'support',
                            'topic.trading',
                            fallback: 'Trading',
                          ),
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
                          label: content.text(
                            'support',
                            'topic.account',
                            fallback: 'Account',
                          ),
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

              return SizedBox.expand(child: Column(children: columnChildren));
            },
          ),
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
                        child: const CircularProgressIndicator(
                          strokeWidth: 1.6,
                        ),
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
