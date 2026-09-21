import '../widgets/app_page_scaffold.dart';
import '../l10n/app_language.dart';
import 'package:flutter/material.dart';

import '../app_config.dart';
import '../services/client_account_service.dart';
import '../theme/app_motion.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/number_formatters.dart';
import '../widgets/app_card.dart';
import '../widgets/app_feedback.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key, this.accountService});
  final ClientAccountService? accountService;

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  late final service = widget.accountService ?? ClientAccountService();
  bool _fetching = false;
  final Set<String> markingRead = <String>{};
  List<Map<String, dynamic>> items = const [];
  bool loading = true;
  bool markingAll = false;
  String? errorMessage;
  int _loadGeneration = 0;

  bool get hasUnread => items.any((item) => item['readAt'] == null);
  int get unreadCount => items.where((item) => item['readAt'] == null).length;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    _loadGeneration++;
    super.dispose();
  }

  Future<void> load() async {
    if (!mounted || _fetching || markingAll || markingRead.isNotEmpty) return;
    final generation = ++_loadGeneration;
    _fetching = true;
    if (mounted) {
      setState(() {
        loading = true;
        errorMessage = null;
      });
    }
    try {
      final result = await service.notifications();
      if (!mounted || generation != _loadGeneration) return;
      setState(() => items = result);
    } catch (_) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() => errorMessage = 'Unable to load notifications');
    } finally {
      _fetching = false;
      if (mounted && generation == _loadGeneration) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> markRead(Map<String, dynamic> item) async {
    final id = item['id']?.toString() ?? '';
    if (_fetching ||
        markingAll ||
        id.isEmpty ||
        item['readAt'] != null ||
        markingRead.contains(id)) {
      return;
    }
    setState(() => markingRead.add(id));
    try {
      await service.readNotification(id);
      if (!mounted) return;
      setState(
        () => items = items
            .map(
              (current) => current['id']?.toString() == id
                  ? {...current, 'readAt': DateTime.now().toIso8601String()}
                  : current,
            )
            .toList(),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: AppText('Unable to mark notification as read')),
      );
    } finally {
      if (mounted) setState(() => markingRead.remove(id));
    }
  }

  Future<void> markAllRead() async {
    if (!hasUnread || markingAll || _fetching || markingRead.isNotEmpty) return;
    setState(() => markingAll = true);
    try {
      await service.readAllNotifications();
      if (!mounted) return;
      final readAt = DateTime.now().toIso8601String();
      setState(() {
        for (final item in items) {
          item['readAt'] ??= readAt;
        }
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: AppText('Unable to mark all notifications')),
      );
    } finally {
      if (mounted) setState(() => markingAll = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppPageScaffold(
    backgroundColor: const Color(0xFFF7F9FC),
    appBar: AppBar(
      title: const AppText('Notifications'),
      actions: [
        if (hasUnread)
          IconButton(
            tooltip: 'Mark all as read',
            constraints: const BoxConstraints(
              minWidth: AppMotion.tapTarget,
              minHeight: AppMotion.tapTarget,
            ),
            onPressed: markingAll || loading || markingRead.isNotEmpty
                ? null
                : markAllRead,
            icon: markingAll
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.done_all_rounded),
          ),
        IconButton(
          tooltip: 'Refresh',
          constraints: const BoxConstraints(
            minWidth: AppMotion.tapTarget,
            minHeight: AppMotion.tapTarget,
          ),
          onPressed: loading || markingAll || markingRead.isNotEmpty
              ? null
              : load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: AppStatusSwitch(
      switchKey: '$loading|$errorMessage|${items.length}',
      child: loading && items.isEmpty
        ? const AppLoadingView(message: 'Loading notifications')
        : errorMessage != null && items.isEmpty
        ? AppErrorView(
            title: 'Unable to load notifications',
            message: 'The server did not return notifications. You can retry.',
            onRetry: load,
          )
        : items.isEmpty
        ? const AppEmptyState(
            title: 'No notifications yet',
            message: 'Account and order updates will appear here when the server sends them.',
            icon: Icons.notifications_none,
          )
        : RefreshIndicator(
            onRefresh: load,
            child: ListView.builder(
              padding: AppSpacing.page,
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: items.length + 1,
              itemBuilder: (_, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: Row(
                      children: [
                        const Expanded(
                          child: AppText(
                            'Recent updates',
                            style: AppTypography.titleMedium,
                          ),
                        ),
                        AppText(
                          unreadCount == 0
                              ? 'All caught up'
                              : '$unreadCount unread',
                          style: AppTypography.caption.copyWith(
                            color: unreadCount == 0
                                ? AppConfig.textSecondaryColor
                                : AppConfig.primaryColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                final item = items[index - 1];
                final unread = item['readAt'] == null;
                final type = item['type']?.toString();
                final paymentRequired = type == 'IPO_PAYMENT_REQUIRED';
                final settled = type == 'IPO_ALLOTMENT_SETTLED';
                final id = item['id']?.toString() ?? '';
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: AppCard(
                    backgroundColor: paymentRequired
                        ? const Color(0xFFFFFBEB)
                        : settled
                        ? const Color(0xFFECFDF5)
                        : unread
                        ? const Color(0xFFF1F6FF)
                        : Colors.white,
                    onTap: unread ? () => markRead(item) : null,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: paymentRequired
                              ? const Color(0xFFB45309).withValues(alpha: 0.12)
                              : settled
                              ? const Color(0xFF047857).withValues(alpha: 0.12)
                              : unread
                              ? const Color(0xFFDDEAFF)
                              : const Color(0xFFF1F5F9),
                          child: Icon(
                            _icon(item['type']?.toString()),
                            size: 20,
                            color: paymentRequired
                                ? const Color(0xFFB45309)
                                : settled
                                ? const Color(0xFF047857)
                                : unread
                                ? AppConfig.primaryColor
                                : AppConfig.textSecondaryColor,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AppText(
                                item['title']?.toString() ?? '',
                                style: TextStyle(
                                  fontWeight: unread
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                              AppText(
                                _subtitle(item),
                                maxLines: paymentRequired || settled ? null : 3,
                                overflow: paymentRequired || settled
                                    ? TextOverflow.visible
                                    : TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        if (markingRead.contains(id))
                          const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else if (unread)
                          Semantics(
                            label: 'Unread',
                            child: Container(
                              width: 9,
                              height: 9,
                              decoration: const BoxDecoration(
                                color: AppConfig.primaryColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
    ),
  );

  IconData _icon(String? type) {
    if (type == 'IPO_PAYMENT_REQUIRED') return Icons.warning_amber_rounded;
    if (type == 'IPO_ALLOTMENT_SETTLED') {
      return Icons.check_circle_outline_rounded;
    }
    if (type == 'SUPPORT') return Icons.support_agent;
    if (type == 'OTC') return Icons.handshake_outlined;
    if (type == 'IPO') return Icons.newspaper_outlined;
    if (type == 'BANK_ACCOUNT') return Icons.account_balance_outlined;
    if (type == 'WITHDRAWAL') return Icons.account_balance_wallet_outlined;
    if (type == 'TRADE') return Icons.swap_horiz_rounded;
    if (type == 'SECURITY') return Icons.security_rounded;
    return Icons.notifications_outlined;
  }

  String _subtitle(Map<String, dynamic> item) {
    final body = item['body']?.toString() ?? '';
    final rawDate = item['createdAt']?.toString();
    if (rawDate == null || rawDate.isEmpty) return body;
    final date = DateTime.tryParse(rawDate)?.toLocal();
    if (date == null) return body;
    final stamp = formatAppDateTime(date);
    return body.isEmpty ? stamp : '$body\n$stamp';
  }
}
