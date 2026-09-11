import '../../l10n/app_language.dart';
import 'package:flutter/material.dart';

import '../../app_config.dart';
import '../../models/institutional_opportunity.dart';
import '../../services/otc_service.dart';
import '../../utils/number_formatters.dart';
import '../responsive_empty_state.dart';

class OtcTab extends StatefulWidget {
  const OtcTab({super.key});

  @override
  State<OtcTab> createState() => _OtcTabState();
}

class _OtcTabState extends State<OtcTab> {
  final OtcService service = OtcService();
  List<InstitutionalStock> offers = const [];
  List<OtcOrderRecord> orders = const [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final result = await Future.wait([service.offers(), service.orders()]);
      if (!mounted) return;
      setState(() {
        offers = result[0] as List<InstitutionalStock>;
        orders = result[1] as List<OtcOrderRecord>;
        loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = offers;

    if (loading) return const Center(child: CircularProgressIndicator());
    if (items.isEmpty && orders.isEmpty) {
      return const ResponsiveEmptyState(
        icon: Icons.handshake_outlined,
        title: 'No OTC opportunities available',
        subtitle:
            'Backend-approved opportunities will appear here during the trading session.',
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: items.length + orders.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index >= items.length) {
            return _orderCard(orders[index - items.length]);
          }
          final item = items[index];

          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8EEFA),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.handshake_outlined,
                          color: AppConfig.primaryColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppText(
                              item.symbol,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 2),
                            AppText(
                              item.companyName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                      AppText(
                        item.status,
                        style: const TextStyle(
                          color: AppConfig.primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: _value(
                          'Market Price',
                          formatPrice(item.marketPrice),
                        ),
                      ),
                      Expanded(
                        child: _value(
                          'Discount Price',
                          formatPrice(item.price),
                          valueColor: AppConfig.gainColor,
                        ),
                      ),
                    ],
                  ),
                  if (item.marketPrice > item.price && item.price > 0)
                    AppText(
                      'Settlement uses discount price · Save ${formatPrice(item.marketPrice - item.price)}',
                      style: const TextStyle(
                        color: AppConfig.gainColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: item.price > 0
                          ? () => _submitDialog(item)
                          : null,
                      icon: const Icon(Icons.shopping_cart_checkout_rounded),
                      label: const AppText('Buy'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _submitDialog(InstitutionalStock item) async {
    final quantity = TextEditingController(text: '1');
    final key = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: AppText('Buy ${item.symbol}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppText('Market price ${formatPrice(item.marketPrice)}'),
            AppText(
              'Settlement price ${formatPrice(item.price)}',
              style: const TextStyle(
                color: AppConfig.gainColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: quantity,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Quantity'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: key,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 4,
              decoration: const InputDecoration(
                labelText: '4-digit transaction key',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const AppText('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const AppText('Submit'),
          ),
        ],
      ),
    );
    if (submitted != true) return;
    try {
      await service.submit(item.id, int.tryParse(quantity.text) ?? 0, key.text);
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: AppText('OTC order submitted · Pending review'),
        ),
      );
    } on OtcException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: AppText(error.message)));
      }
    }
  }

  Widget _orderCard(OtcOrderRecord order) {
    final color = order.status == 'APPROVED'
        ? AppConfig.gainColor
        : order.status == 'REJECTED'
        ? AppConfig.lossColor
        : Colors.orange.shade700;
    final label = order.status == 'APPROVED'
        ? 'Approved · In holdings'
        : order.status == 'REJECTED'
        ? 'Rejected'
        : 'Pending review';
    return Card(
      child: ListTile(
        leading: Icon(Icons.schedule_rounded, color: color),
        title: AppText(
          '${order.symbol} · ${order.quantity} shares',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: AppText(
          order.reviewNote?.isNotEmpty == true
              ? order.reviewNote!
              : order.orderNo,
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            AppText(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
            AppText(
              formatPrice(order.price),
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _value(String label, String value, {Color? valueColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(
          label,
          style: const TextStyle(color: Colors.black45, fontSize: 12),
        ),
        const SizedBox(height: 4),
        AppText(
          value,
          style: TextStyle(fontWeight: FontWeight.w600, color: valueColor),
        ),
      ],
    );
  }
}
