import '../../l10n/app_language.dart';
import 'package:flutter/material.dart';

import '../../app_config.dart';
import '../../models/institutional_opportunity.dart';
import '../../services/otc_service.dart';
import '../../utils/number_formatters.dart';
import '../responsive_empty_state.dart';
import 'product_offer_card.dart';

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

          return ProductOfferCard(
            name: item.companyName,
            symbol: item.symbol,
            type: 'OTC',
            marketPrice: item.marketPrice,
            offerPrice: item.price,
            onTrade: item.price > 0 ? () => _submitDialog(item) : null,
          );        },
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
              maxLength: 6,
              inputFormatters: const [],
              decoration: const InputDecoration(
                labelText: '6-digit transaction PIN',
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

}

