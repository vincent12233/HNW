import 'package:flutter/material.dart';

import '../../app_config.dart';
import '../../models/ipo.dart';
import '../../models/pending_order.dart';
import '../../utils/number_formatters.dart';
import '../stock_logo.dart';
import 'pending_orders_tab.dart';

class PendingCenterTab extends StatefulWidget {
  const PendingCenterTab({
    super.key,
    required this.pendingOrders,
    required this.ipoApplications,
    required this.onAllocateIpo,
  });

  final List<PendingOrder> pendingOrders;
  final List<IpoApplication> ipoApplications;

  final void Function(String applicationId, int allocatedQuantity)
  onAllocateIpo;

  @override
  State<PendingCenterTab> createState() => _PendingCenterTabState();
}

class _PendingCenterTabState extends State<PendingCenterTab> {
  int selectedSection = 0;

  final List<String> sections = const ['Orders', 'IPO Applications'];

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
                label: Text(sections[index]),
                selected: selectedSection == index,
                onSelected: (_) {
                  setState(() {
                    selectedSection = index;
                  });
                },
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: selectedSection == 0
              ? PendingOrdersTab(orders: widget.pendingOrders)
              : _buildIpoApplications(),
        ),
      ],
    );
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
              Text(
                'No IPO applications',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
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
                        Text(
                          application.companyName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
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
                    child: Text(
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
                    const Text(
                      'Application',
                      style: TextStyle(color: Colors.black54, fontSize: 12),
                    ),
                    const Spacer(),
                    Text(
                      '#$applicationNumber',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),

              if (application.status == IpoApplicationStatus.applied) ...[
                const SizedBox(height: 14),

                const Text(
                  'Application submitted. Allocation is pending relationship manager review.',
                  style: TextStyle(color: Colors.black54),
                ),
              ],

              if (application.status == IpoApplicationStatus.allocated) ...[
                const Divider(height: 26),

                Row(
                  children: [
                    Expanded(
                      child: _value(
                        'Allocated',
                        '${application.allocatedQuantity} Shares',
                      ),
                    ),
                    Expanded(
                      child: _value(
                        'Subscription Price',
                        formatPrice(application.subscriptionPrice),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                Row(
                  children: [
                    Expanded(
                      child: _value(
                        'Total Amount',
                        formatPrice(application.allocatedAmount),
                      ),
                    ),
                    Expanded(
                      child: _value(
                        'Paid Amount',
                        formatPrice(application.paidAmount),
                        valueColor: AppConfig.gainColor,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                _value(
                  'Outstanding Amount',
                  formatPrice(application.remainingAmount),
                  valueColor: AppConfig.lossColor,
                ),

                if (application.remainingAmount > 0) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFED7AA)),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 18,
                          color: Color(0xFFB45309),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Available account cash has been automatically deducted. '
                            'The remaining amount is IPO debt. Shares will move to Holdings only after the subscription is fully settled.',
                            style: TextStyle(
                              color: Color(0xFF92400E),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],

              if (application.status == IpoApplicationStatus.completed) ...[
                const SizedBox(height: 14),

                const Row(
                  children: [
                    Icon(Icons.check_circle, size: 18, color: Colors.green),
                    SizedBox(width: 8),
                    Text(
                      'Subscription completed',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: _value(
                        'Shares',
                        '${application.allocatedQuantity}',
                      ),
                    ),
                    Expanded(
                      child: _value(
                        'Paid Amount',
                        formatPrice(application.paidAmount),
                        valueColor: AppConfig.gainColor,
                      ),
                    ),
                  ],
                ),
              ],

              if (application.status == IpoApplicationStatus.notAllotted) ...[
                const SizedBox(height: 14),
                const Text(
                  'No shares were allocated for this application.',
                  style: TextStyle(color: Colors.black54),
                ),
              ],

              if (application.status == IpoApplicationStatus.cancelled) ...[
                const SizedBox(height: 14),
                const Text(
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

  int _applicationNumberFor(IpoApplication application) {
    final sameIpoApplications = widget.ipoApplications
        .where((item) => item.ipoId == application.ipoId)
        .toList()
        .reversed
        .toList();

    final index = sameIpoApplications.indexWhere(
      (item) => item.id == application.id,
    );

    if (index < 0) {
      return 1;
    }

    return index + 1;
  }

  Widget _value(String label, String value, {Color? valueColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.black45, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(color: valueColor, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
