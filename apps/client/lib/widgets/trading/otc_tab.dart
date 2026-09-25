import '../../l10n/app_language.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_config.dart';
import '../../models/institutional_opportunity.dart';
import '../../services/app_content_service.dart';
import '../../services/otc_service.dart';
import '../../utils/number_formatters.dart';
import '../app_feedback.dart';
import '../app_status_label.dart';
import '../record_detail_sheet.dart';
import '../app_page_scaffold.dart';
import 'product_offer_card.dart';
import 'trading_guide_card.dart';

class OtcTab extends StatefulWidget {
  const OtcTab({super.key, this.service});

  final OtcService? service;

  @override
  State<OtcTab> createState() => _OtcTabState();
}

class _OtcTabState extends State<OtcTab> {
  late final OtcService service = widget.service ?? OtcService();
  List<InstitutionalStock> offers = const [];
  List<OtcOrderRecord> orders = const [];
  bool loading = true;
  bool submitting = false;
  String? error;
  int _generation = 0;
  Future<void>? _inFlight;

  @override
  void initState() {
    super.initState();
    AppContentService.instance.addListener(_onAppContentChanged);
    unawaited(AppContentService.instance.load());
    _refresh();
  }

  void _onAppContentChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _generation++;
    AppContentService.instance.removeListener(_onAppContentChanged);
    super.dispose();
  }

  Future<void> _refresh() {
    final pending = _inFlight;
    if (pending != null) return pending;
    final request = ++_generation;
    final future = _refreshOnce(request);
    _inFlight = future;
    return future.whenComplete(() {
      if (identical(_inFlight, future)) _inFlight = null;
    });
  }

  Future<void> _refreshOnce(int request) async {
    if (mounted) {
      setState(() {
        loading = true;
      });
    }
    try {
      final result = await Future.wait([service.offers(), service.orders()]);
      if (!mounted || request != _generation) return;
      setState(() {
        offers = result[0] as List<InstitutionalStock>;
        orders = result[1] as List<OtcOrderRecord>;
        loading = false;
        error = null;
      });
    } catch (err) {
      if (!mounted || request != _generation) return;
      setState(() {
        loading = false;
        error = err.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = offers;
    final content = AppContentService.instance.current;
    final guideTitle = content.title('trading', 'guide.otc');
    final guideBody = content.text('trading', 'guide.otc');

    if (loading && offers.isEmpty && orders.isEmpty && error == null) {
      return const AppLoadingView(message: 'Loading OTC orders');
    }
    if (error != null && offers.isEmpty && orders.isEmpty) {
      return AppErrorView(
        title: 'Unable to load OTC',
        message: error,
        onRetry: _refresh,
      );
    }
    if (items.isEmpty && orders.isEmpty) {
      return Column(
        children: [
          if (guideBody.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: TradingGuideCard(title: guideTitle, body: guideBody),
            ),
          Expanded(
            child: AppEmptyState(
              icon: Icons.handshake_outlined,
              title: content.text(
                'trading',
                'otc.empty_title',
                fallback: 'No OTC opportunities available',
              ),
              message: content.text(
                'trading',
                'otc.empty_subtitle',
                fallback:
                    'Backend-approved opportunities will appear here during the trading session.',
              ),
            ),
          ),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount:
            items.length + orders.length + (guideBody.isNotEmpty ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (guideBody.isNotEmpty && index == 0) {
            return TradingGuideCard(title: guideTitle, body: guideBody);
          }
          final offset = guideBody.isNotEmpty ? index - 1 : index;
          if (offset >= items.length) {
            return _orderCard(orders[offset - items.length]);
          }
          final item = items[offset];

          return ProductOfferCard(
            name: item.companyName,
            symbol: item.symbol,
            type: 'OTC',
            marketPrice: item.marketPrice,
            offerPrice: item.price,
            onTrade: item.price > 0 ? () => _submitDialog(item) : null,
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: AppText('Buy ${item.symbol}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppText('Market quote (reference)'),
                  Text(formatPrice(item.marketPrice)),
                  const SizedBox(height: 8),
                  const AppText('Discount settlement price'),
                  Text(
                    formatPrice(item.price),
                    style: const TextStyle(
                      color: AppConfig.gainColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
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
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(4),
              ],
              decoration: const InputDecoration(
                labelText: '4-digit transaction PIN',
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
            onPressed: submitting
                ? null
                : () => Navigator.pop(dialogContext, true),
            child: AppText(submitting ? 'Submitting...' : 'Submit'),
          ),
        ],
      ),
    );
    if (submitted != true) return;
    if (submitting) return;
    setState(() => submitting = true);
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
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  Widget _orderCard(OtcOrderRecord order) {
    final label = displayStatusLabel(
      order.status,
      labels: const {
        'PENDING': 'Pending review',
        'APPROVED': 'Approved',
        'REJECTED': 'Rejected',
      },
    );
    return Card(
      child: ListTile(
        onTap: () => showRecordDetailSheet(
          context,
          title: '${order.symbol} OTC order',
          status: AppLabeledStatus(
            status: order.status,
            labels: const {
              'PENDING': 'Pending review',
              'APPROVED': 'Approved',
              'REJECTED': 'Rejected',
            },
          ),
          rows: [
            ('Order', order.orderNo.isEmpty ? 'Unavailable' : order.orderNo),
            ('Quantity', '${order.quantity}'),
            ('Discount settlement price', formatPrice(order.price)),
            ('Status', label),
            ('Submitted', formatAppDateTime(order.createdAt)),
            (
              'Review note',
              order.reviewNote?.isNotEmpty == true
                  ? order.reviewNote!
                  : 'Unavailable',
            ),
          ],
        ),
        leading: const Icon(Icons.schedule_rounded),
        title: AppText(
          '${order.symbol} · ${order.quantity} shares',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText(label),
            AppText(
              order.reviewNote?.isNotEmpty == true
                  ? order.reviewNote!
                  : (order.orderNo.isEmpty ? 'Unavailable' : order.orderNo),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
