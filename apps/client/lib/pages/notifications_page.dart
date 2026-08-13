import 'package:flutter/material.dart';
import '../services/client_account_service.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});
  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final service = ClientAccountService();
  List<Map<String, dynamic>> items = const [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      items = await service.notifications();
      await service.readAllNotifications();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Notifications'),
      actions: [IconButton(onPressed: load, icon: const Icon(Icons.refresh))],
    ),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : items.isEmpty
        ? const Center(child: Text('No notifications yet'))
        : RefreshIndicator(
            onRefresh: load,
            child: ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, index) {
                final item = items[index];
                return ListTile(
                  leading: CircleAvatar(
                    child: Icon(_icon(item['type']?.toString())),
                  ),
                  title: Text(item['title']?.toString() ?? ''),
                  subtitle: Text(item['body']?.toString() ?? ''),
                  trailing: item['readAt'] == null
                      ? Container(
                          width: 9,
                          height: 9,
                          decoration: const BoxDecoration(
                            color: Colors.red,
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
    return Icons.notifications_outlined;
  }
}
