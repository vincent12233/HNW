import '../widgets/app_page_scaffold.dart';
import '../l10n/app_language.dart';
import 'package:flutter/material.dart';

import '../app_config.dart';
import '../services/client_account_service.dart';
import '../theme/app_motion.dart';
import '../theme/app_spacing.dart';

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

  bool get hasUnread => items.any((item) => item['readAt'] == null);
  int get unreadCount => items.where((item) => item['readAt'] == null).length;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (!mounted || _fetching || markingAll || markingRead.isNotEmpty) return;
    _fetching = true;
    if (mounted) {
      setState(() {
        loading = true;
        errorMessage = null;
      });
    }
    try {
      final result = await service.notifications();
      if (!mounted) return;
      setState(() => items = result);
    } catch (_) {
      if (!mounted) return;
      setState(() => errorMessage = 'Unable to load notifications');
    } finally {
      _fetching = false;
      if (mounted) setState(() => loading = false);
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
        ? const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: AppSpacing.md),
                AppText('Loading notifications'),
              ],
            ),
          )
        : errorMessage != null && items.isEmpty
        ? AppEmptyState(
            title: 'Unable to load notifications',
            message: 'The server did not return notifications. You can retry.',
            icon: Icons.cloud_off_outlined,
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
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: items.length + 1,
              itemBuilder: (_, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(2, 0, 2, 10),
                    child: Row(
                      children: [
                        const Expanded(
                          child: AppText(
                            'Recent updates',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        AppText(
                          unreadCount == 0
                              ? 'All caught up'
                              : '$unreadCount unread',
                          style: TextStyle(
                            color: unreadCount == 0
                                ? AppConfig.textSecondaryColor
                                : AppConfig.primaryColor,
                            fontSize: 12,
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
                final outcomeColor = paymentRequired
                    ? const Color(0xFFB45309)
                    : settled
                    ? const Color(0xFF047857)
                    : null;
                final id = item['id']?.toString() ?? '';
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  elevation: 0,
                  color: paymentRequired
                      ? const Color(0xFFFFFBEB)
                      : settled
                      ? const Color(0xFFECFDF5)
                      : unread
                      ? const Color(0xFFF1F6FF)
                      : Colors.white,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    onTap: unread ? () => markRead(item) : null,
                    leading: CircleAvatar(
                      radius: 20,
                      backgroundColor:
                          outcomeColor?.withValues(alpha: 0.12) ??
                          (unread
                              ? const Color(0xFFDDEAFF)
                              : const Color(0xFFF1F5F9)),
                      child: Icon(
                        _icon(item['type']?.toString()),
                        size: 20,
                        color:
                            outcomeColor ??
                            (unread
                                ? AppConfig.primaryColor
                                : AppConfig.textSecondaryColor),
                      ),
                    ),
                    title: AppText(
                      item['title']?.toString() ?? '',
                      style: TextStyle(
                        fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    subtitle: AppText(
                      _subtitle(item),
                      maxLines: paymentRequired || settled ? null : 3,
                      overflow: paymentRequired || settled
                          ? TextOverflow.visible
                          : TextOverflow.ellipsis,
                    ),
                    trailing: markingRead.contains(id)
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : unread
                        ? Container(
                            width: 9,
                            height: 9,
                            decoration: const BoxDecoration(
                              color: AppConfig.primaryColor,
                              shape: BoxShape.circle,
                            ),
                          )
                        : null,
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
    final ist = date.toUtc().add(const Duration(hours: 5, minutes: 30));
    String two(int number) => number.toString().padLeft(2, '0');
    final stamp =
        '${two(ist.day)}/${two(ist.month)}/${ist.year} '
        '${two(ist.hour)}:${two(ist.minute)} IST';
    return body.isEmpty ? stamp : '$body\n$stamp';
  }
}
