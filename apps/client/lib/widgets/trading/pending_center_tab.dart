import '../../l10n/app_language.dart';
import 'package:flutter/material.dart';

import '../../models/ipo.dart';
import '../../models/trading_order.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/number_formatters.dart';
import '../stock_logo.dart';
import 'order_card.dart';

class PendingCenterTab extends StatefulWidget {
  const PendingCenterTab({
    super.key,
    required this.activeOrders,
    required this.ipoApplications,
    this.onCancel,
  });

  final List<TradingOrder> activeOrders;
  final List<IpoApplication> ipoApplications;
  final Future<String?> Function(TradingOrder order)? onCancel;

  @override
  State<PendingCenterTab> createState() => _PendingCenterTabState();
}

class _PendingCenterTabState extends State<PendingCenterTab> {
  int selectedSection = 0;
  final List<String> sections = const ['Open orders', 'IPO Applications'];

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
                selectedColor: AppColors.brandPrimary,
                backgroundColor: AppColors.surface,
                labelStyle: AppTypography.labelMedium.copyWith(
                  color: selectedSection == index
                      ? AppColors.textInverse
                      : AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
                side: BorderSide(
                  color: selectedSection == index
                      ? AppColors.brandPrimary
                      : AppColors.border,
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
    final orders = List<TradingOrder>.of(widget.activeOrders)
      ..sort((a, b) => b.placedAt.compareTo(a.placedAt));

    if (orders.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.schedule_outlined,
                size: 64,
                color: AppColors.textDisabled,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppText(
                'No pending orders',
                style: AppTypography.headline.copyWith(fontSize: 20),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppText(
                'Open, pending, and partially filled orders will appear here.',
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
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
      itemBuilder: (context, index) => OrderCard(
        order: orders[index],
        onCancel: widget.onCancel,
      ),
    );
  }

  Widget _buildIpoApplications() {
    if (widget.ipoApplications.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.assignment_outlined,
                size: 64,
                color: AppColors.textDisabled,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppText(
                'No IPO applications',
                style: AppTypography.headline.copyWith(fontSize: 20),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppText(
                'Your IPO applications will appear here.',
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
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
          IpoApplicationStatus.completed => AppColors.gain,
          IpoApplicationStatus.notAllotted => AppColors.loss,
          IpoApplicationStatus.cancelled => AppColors.neutral,
          IpoApplicationStatus.allocated => AppColors.warning,
          IpoApplicationStatus.applied => AppColors.brandPrimary,
        };

        return Container(
          padding: AppSpacing.card,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.borderLg,
            border: Border.all(color: AppColors.border),
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
              if (application.needsSubscription) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFDBA74)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(
                        'Outstanding Payment: ${formatPrice(application.remainingAmount)}',
                        style: const TextStyle(
                          color: Color(0xFF9A3412),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const AppText(
                        'Contact support to add funds. Payment is applied automatically after deposit.',
                        style: TextStyle(
                          color: Color(0xFF9A3412),
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
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
                    Icon(Icons.check_circle, size: 18, color: AppColors.gain),
                    SizedBox(width: AppSpacing.sm),
                    AppText(
                      'Subscription completed',
                      style: TextStyle(
                        color: AppColors.gain,
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
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: needsFunds ? AppColors.lossSoft : AppColors.gainSoft,
                    borderRadius: AppRadius.borderMd,
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
                          color: needsFunds ? AppColors.loss : AppColors.gain,
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
