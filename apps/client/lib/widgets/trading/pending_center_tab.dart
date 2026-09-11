import '../../l10n/app_language.dart';
import 'package:flutter/material.dart';

import '../../app_config.dart';
import '../../models/ipo.dart';
import '../../models/trading_order.dart';
import '../../services/trading_service.dart';
import '../../utils/number_formatters.dart';
import '../stock_logo.dart';

class PendingCenterTab extends StatefulWidget {
  const PendingCenterTab({
    super.key,
    required this.activeOrders,
    required this.ipoApplications,
    this.onOrderCancelled,
  });

  final List<TradingOrder> activeOrders;
  final List<IpoApplication> ipoApplications;
  final VoidCallback? onOrderCancelled;

  @override
  State<PendingCenterTab> createState() => _PendingCenterTabState();
}

class _PendingCenterTabState extends State<PendingCenterTab> {
  final TradingService _tradingService = TradingService();
  final Set<String> _locallyCancelledOrderIds = <String>{};
  final Set<String> _cancellingOrderIds = <String>{};

  int selectedSection = 0;
  final List<String> sections = const ['Order Book', 'IPO Applications'];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 46,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: sections.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              return ChoiceChip(
                label: AppText(sections[index]),
                selected: selectedSection == index,
                labelStyle: TextStyle(
                  color: selectedSection == index
                      ? Colors.white
                      : AppConfig.textPrimaryColor,
                  fontWeight: FontWeight.w700,
                ),
                onSelected: (_) => setState(() => selectedSection = index),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: selectedSection == 0
              ? _buildActiveOrders()
              : _buildIpoApplications(),
        ),
      ],
    );
  }

  Widget _buildActiveOrders() {
    final orders = widget.activeOrders
        .where(
          (order) =>
              order.orderId == null ||
              !_locallyCancelledOrderIds.contains(order.orderId),
        )
        .toList();

    if (orders.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.schedule_outlined, size: 64, color: Colors.black38),
              SizedBox(height: 16),
              AppText(
                'No pending orders',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              AppText(
                'Open and partially filled orders will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _pendingOrderCard(orders[index]),
    );
  }

  Widget _pendingOrderCard(TradingOrder order) {
    final sideColor = order.isBuy ? AppConfig.gainColor : AppConfig.lossColor;
    final orderId = order.orderId;
    final cancelling = orderId != null && _cancellingOrderIds.contains(orderId);
    final displayPrice = order.limitPrice ?? order.price;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StockLogo(symbol: order.symbol, size: 42),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      order.symbol,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    AppText(
                      '${order.type == 'LIMIT' ? 'Limit Order' : 'Market Order'} • ${order.timeInForce}',
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: sideColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: AppText(
                  order.isBuy ? 'BUY' : 'SELL',
                  style: TextStyle(
                    color: sideColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 26),
          Row(
            children: [
              Expanded(child: _orderValue('Quantity', '${order.quantity}')),
              Expanded(
                child: _orderValue(
                  order.isLimit ? 'Limit Price' : 'Price',
                  displayPrice > 0 ? formatPrice(displayPrice) : '--',
                ),
              ),
              Expanded(
                child: _orderValue(
                  'Status',
                  order.status == 'PARTIALLY_FILLED' ? 'Partial' : 'Open',
                ),
              ),
            ],
          ),
          if (order.filledQuantity > 0) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _orderValue(
                    'Filled Quantity',
                    '${order.filledQuantity}',
                  ),
                ),
                Expanded(
                  child: _orderValue(
                    'Remaining Quantity',
                    '${order.remainingQuantity}',
                  ),
                ),
                const Expanded(child: SizedBox()),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: AppText(
                  order.formattedTime,
                  style: const TextStyle(color: Colors.black45, fontSize: 12),
                ),
              ),
              OutlinedButton(
                onPressed: orderId == null || cancelling
                    ? null
                    : () => _confirmCancel(order),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppConfig.lossColor,
                ),
                child: AppText(cancelling ? 'Cancelling...' : 'Cancel Order'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _orderValue(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(
          label,
          style: const TextStyle(color: Colors.black45, fontSize: 12),
        ),
        const SizedBox(height: 4),
        AppText(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    );
  }

  Future<void> _confirmCancel(TradingOrder order) async {
    final orderId = order.orderId;
    if (orderId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const AppText('Cancel Order?'),
        content: AppText(
          'Cancel the remaining ${order.remainingQuantity} shares of '
          '${order.symbol} ${order.isBuy ? 'BUY' : 'SELL'} order?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const AppText('Keep Order'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: AppConfig.lossColor),
            child: const AppText('Cancel Order'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _cancellingOrderIds.add(orderId));
    try {
      await _tradingService.cancelOrder(orderId);
      if (!mounted) return;
      setState(() {
        _cancellingOrderIds.remove(orderId);
        _locallyCancelledOrderIds.add(orderId);
      });
      widget.onOrderCancelled?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: AppText('${order.symbol} order cancelled')),
      );
    } on TradingException catch (error) {
      if (!mounted) return;
      setState(() => _cancellingOrderIds.remove(orderId));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: AppText(error.message)));
    }
  }

  Widget _buildIpoApplications() {
    if (widget.ipoApplications.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.assignment_outlined, size: 64, color: Colors.black38),
              SizedBox(height: 16),
              AppText(
                'No IPO applications',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              AppText(
                'Your IPO applications will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: widget.ipoApplications.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final application = widget.ipoApplications[index];
        final applicationNumber = _applicationNumberFor(application);
        final statusColor = switch (application.status) {
          IpoApplicationStatus.completed => AppConfig.gainColor,
          IpoApplicationStatus.notAllotted => AppConfig.lossColor,
          IpoApplicationStatus.cancelled => AppConfig.neutralColor,
          IpoApplicationStatus.allocated => const Color(0xFFB45309),
          IpoApplicationStatus.applied => AppConfig.primaryColor,
        };

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  StockLogo(symbol: application.symbol, size: 42),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppText(
                          application.companyName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 3),
                        AppText(
                          application.symbol,
                          style: const TextStyle(color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: AppText(
                      application.statusLabel,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F8FA),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const AppText(
                      'Application',
                      style: TextStyle(color: Colors.black54, fontSize: 12),
                    ),
                    const Spacer(),
                    AppText(
                      '#$applicationNumber',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              if (application.status == IpoApplicationStatus.applied) ...[
                const SizedBox(height: 14),
                const AppText(
                  'Application submitted. Allocation is pending relationship manager review.',
                  style: TextStyle(color: Colors.black54),
                ),
              ],
              if (application.hasAllocation) ...[
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () => _showIpoDetails(application),
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: const AppText('View Details'),
                ),
              ],
              if (application.status == IpoApplicationStatus.completed) ...[
                const SizedBox(height: 14),
                const Row(
                  children: [
                    Icon(Icons.check_circle, size: 18, color: Colors.green),
                    SizedBox(width: 8),
                    AppText(
                      'Subscription completed',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
              if (application.status == IpoApplicationStatus.notAllotted) ...[
                const SizedBox(height: 14),
                const AppText(
                  'No shares were allocated for this application.',
                  style: TextStyle(color: Colors.black54),
                ),
              ],
              if (application.status == IpoApplicationStatus.cancelled) ...[
                const SizedBox(height: 14),
                const AppText(
                  'This application was cancelled.',
                  style: TextStyle(color: Colors.black54),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _showIpoDetails(IpoApplication application) async {
    final needsFunds = application.remainingAmount > 0;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Expanded(child: AppText('${application.companyName} IPO Details')),
            IconButton(
              tooltip: 'Close',
              onPressed: () => Navigator.pop(dialogContext),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: needsFunds
                        ? const Color(0xFFFFF1F2)
                        : const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(
                        needsFunds
                            ? 'Outstanding Payment: ${formatPrice(application.remainingAmount)}'
                            : 'Subscription completed',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: needsFunds
                              ? const Color(0xFFB42318)
                              : const Color(0xFF047857),
                        ),
                      ),
                      const SizedBox(height: 10),
                      AppText(
                        needsFunds
                            ? 'Your IPO allotment is confirmed. Add the required funds to complete your subscription. No further action is needed after funds arrive.'
                            : 'Your allocated shares have been added to your holdings.',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const AppText(
                  'Subscription Details',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const Divider(height: 24),
                _value('Allocated Shares', '${application.allocatedQuantity}'),
                const Divider(height: 24),
                _value(
                  'Subscription Price',
                  formatPrice(application.subscriptionPrice),
                ),
                const Divider(height: 24),
                _value(
                  'Subscription Total',
                  formatPrice(application.allocatedAmount),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  int _applicationNumberFor(IpoApplication application) {
    final sameIpoApplications = widget.ipoApplications
        .where((item) => item.ipoId == application.ipoId)
        .toList()
        .reversed
        .toList();
    final index = sameIpoApplications.indexWhere(
      (item) => item.id == application.id,
    );
    return index < 0 ? 1 : index + 1;
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
          style: TextStyle(color: valueColor, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
