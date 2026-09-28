part of 'support_chat_page.dart';

extension _SupportChatControls on _SupportChatPageState {
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
          color: AppColors.brandDark,
          borderRadius: BorderRadius.circular(m.panelRadius * 0.85),
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
              tooltip: tr('Close'),
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
                      color: _error != null
                          ? const Color(0xFFEF4444)
                          : _opening
                          ? const Color(0xFFFBBF24)
                          : const Color(0xFF94A3B8),
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
                    _appContent.current.text(
                      'support',
                      'header_title',
                      fallback: 'Online Customer Service',
                    ),
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
                        ? 'Opening chat…'
                        : _error != null
                        ? 'Could not open chat'
                        : (_chatAvailable
                            ? 'Opens external customer chat'
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
        color: const Color(0xFFDCE9FF),
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
                onPressed: () => _updateState(() => _noticeVisible = false),
                tooltip: tr('Dismiss hours notice'),
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
                            ? 'Opening chat…'
                            : (_chatAvailable
                                  ? 'Message opens in the external chat'
                                  : _appContent.current.text(
                                      'support',
                                      'composer_hint',
                                      fallback: 'Use a topic or open on mobile',
                                    )),
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
              child: Semantics(
                button: true,
                label: _chatAvailable
                    ? 'Open external customer chat'
                    : 'Retry customer chat',
                child: SizedBox(
                  width: m.sendButtonSize,
                  height: m.sendButtonSize,
                  child: Icon(
                    _chatAvailable
                        ? Icons.send_rounded
                        : Icons.refresh_rounded,
                    color: Colors.white,
                    size: 18 * m.scale,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}