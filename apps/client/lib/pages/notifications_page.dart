import 'package:flutter/material.dart';

import '../services/client_account_service.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final service = ClientAccountService();
  final Set<String> markingRead = <String>{};
  List<Map<String, dynamic>> items = const [];
  bool loading = true;
  bool markingAll = false;
  String? errorMessage;

  bool get hasUnread => items.any((item) => item['readAt'] == null);

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
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
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> markRead(Map<String, dynamic> item) async {
    final id = item['id']?.toString() ?? '';
    if (id.isEmpty || item['readAt'] != null || markingRead.contains(id)) {
      return;
    }
    setState(() => markingRead.add(id));
    try {
      await service.readNotification(id);
      if (!mounted) return;
      setState(() => item['readAt'] = DateTime.now().toIso8601String());
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to mark notification as read')),
      );
    } finally {
      if (mounted) setState(() => markingRead.remove(id));
    }
  }

  Future<void> markAllRead() async {
    if (!hasUnread || markingAll) return;
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
        const SnackBar(content: Text('Unable to mark all notifications')),
      );
    } finally {
      if (mounted) setState(() => markingAll = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Notifications'),
      actions: [
        if (hasUnread)
          IconButton(
            tooltip: 'Mark all as read',
            onPressed: markingAll ? null : markAllRead,
            icon: markingAll
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.done_all_rounded),
          ),
        IconButton(
          tooltip: 'Refresh',
          onPressed: loading ? null : load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: loading && items.isEmpty
        ? const Center(child: CircularProgressIndicator())
        : errorMessage != null && items.isEmpty
        ? _ErrorState(message: errorMessage!, onRetry: load)
        : items.isEmpty
        ? const Center(child: Text('No notifications yet'))
        : RefreshIndicator(
            onRefresh: load,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, index) {
                final item = items[index];
                final unread = item['readAt'] == null;
                final id = item['id']?.toString() ?? '';
                return ListTile(
                  tileColor: unread ? const Color(0xFFF4F8FF) : null,
                  onTap: unread ? () => markRead(item) : null,
                  leading: CircleAvatar(
                    backgroundColor: unread
                        ? const Color(0xFFE3EEFF)
                        : const Color(0xFFF1F5F9),
                    child: Icon(_icon(item['type']?.toString())),
                  ),
                  title: Text(
                    item['title']?.toString() ?? '',
                    style: TextStyle(
                      fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(item['body']?.toString() ?? ''),
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
                            color: Color(0xFF0878F9),
                            shape: BoxShape.circle,
                          ),
                        )
                      : null,
                );
              },
            ),
          ),
  );

  IconData _icon(String? type) {
    if (type == 'SUPPORT') return Icons.support_agent;
    if (type == 'OTC') return Icons.handshake_outlined;
    if (type == 'IPO') return Icons.newspaper_outlined;
    if (type == 'BANK_ACCOUNT') return Icons.account_balance_outlined;
    if (type == 'WITHDRAWAL') return Icons.account_balance_wallet_outlined;
    if (type == 'TRADE') return Icons.swap_horiz_rounded;
    if (type == 'SECURITY') return Icons.security_rounded;
    return Icons.notifications_outlined;
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.cloud_off_outlined, size: 44),
        const SizedBox(height: 12),
        Text(message),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    ),
  );
}
