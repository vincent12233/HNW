import '../../l10n/app_language.dart';
import 'package:flutter/material.dart';

import '../../app_config.dart';
import '../../models/ipo.dart';
import '../../utils/number_formatters.dart';
import '../stock_logo.dart';
import '../responsive_empty_state.dart';

class IpoTab extends StatefulWidget {
  const IpoTab({
    super.key,
    required this.ipos,
    required this.applications,
    required this.onApply,
  });

  final List<Ipo> ipos;
  final List<IpoApplication> applications;
  final ValueChanged<Ipo> onApply;

  @override
  State<IpoTab> createState() => _IpoTabState();
}

class _IpoTabState extends State<IpoTab> {
  int selectedSection = 0;

  final List<String> sections = const ['Upcoming', 'Open', 'Closed', 'All'];

  int _applicationCount(String ipoId) {
    return widget.applications
        .where((application) => application.ipoId == ipoId)
        .length;
  }

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
        Expanded(child: _buildIpoList()),
      ],
    );
  }

  Widget _buildIpoList() {
    final filtered = widget.ipos.where((ipo) {
      if (selectedSection == 0) return ipo.status == IpoStatus.upcoming;
      if (selectedSection == 1) return ipo.status == IpoStatus.open;
      if (selectedSection == 2) return ipo.status == IpoStatus.closed;
      return true;
    }).toList();

    if (filtered.isEmpty) {
      return ResponsiveEmptyState(
        icon: Icons.campaign_outlined,
        title: selectedSection == 1
            ? 'No IPOs open for application'
            : 'No IPO records',
        subtitle: selectedSection == 1
            ? 'New IPO opportunities will appear here when applications open.'
            : 'Your IPO applications and available offers will appear here.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final ipo = filtered[index];

        final hasDiscount = ipo.discountAmount > 0;
        final applicationCount = _applicationCount(ipo.id);
        final reachedLimit = applicationCount >= 5;

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
                  StockLogo(symbol: ipo.symbol, size: 46),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppText(
                          ipo.companyName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 3),
                        AppText(
                          ipo.symbol,
                          style: const TextStyle(color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: ipo.status == IpoStatus.open
                          ? const Color(0xFFE8F7F3)
                          : const Color(0xFFFFF7E8),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: AppText(
                      ipo.statusLabel,
                      style: TextStyle(
                        color: ipo.status == IpoStatus.open
                            ? AppConfig.gainColor
                            : const Color(0xFFB45309),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),

              const Divider(height: 26),

              Row(
                children: [
                  Expanded(
                    child: _value('Market Price', formatPrice(ipo.marketPrice)),
                  ),
                  Expanded(
                    child: _value(
                      'Subscription Price',
                      formatPrice(ipo.subscriptionPrice),
                    ),
                  ),
                ],
              ),

              if (ipo.marketPrice > 0 && ipo.subscriptionPrice > 0) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.trending_up_rounded,
                      size: 16,
                      color: AppConfig.gainColor,
                    ),
                    const SizedBox(width: 6),
                    AppText(
                      '${ipo.discountPercent.toStringAsFixed(2)}% expected return',
                      style: const TextStyle(
                        color: AppConfig.gainColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: _value(
                      'Discount',
                      hasDiscount
                          ? '${formatPrice(ipo.discountAmount)} '
                                '(${ipo.discountPercent.toStringAsFixed(2)}%)'
                          : '--',
                      valueColor: hasDiscount
                          ? AppConfig.gainColor
                          : AppConfig.neutralColor,
                    ),
                  ),
                  Expanded(child: _value('Lot Size', '${ipo.lotSize} Shares')),
                ],
              ),

              if (ipo.status == IpoStatus.open) ...[
                const SizedBox(height: 18),

                if (applicationCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AppText(
                      'Applications: $applicationCount / 5',
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                  ),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: reachedLimit
                        ? null
                        : () {
                            _confirmApply(ipo);
                          },
                    child: AppText(reachedLimit ? 'Applied 5/5' : 'Apply Now'),
                  ),
                ),
              ],
            ],
          ),
        );
      },
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
          style: TextStyle(color: valueColor, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Future<void> _confirmApply(Ipo ipo) async {
    final currentCount = _applicationCount(ipo.id);

    if (currentCount >= 5) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const AppText('IPO Application'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(
                ipo.companyName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              AppText(
                ipo.symbol,
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 18),
              AppText(
                'Submit IPO application ${currentCount + 1} of 5?\n\n'
                'You will be notified when your allotment is announced. '
                'Payment is automatic after allotment. If more funds are '
                'needed, we will show the amount to add.',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const AppText('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const AppText('Apply'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    widget.onApply(ipo);
  }
}
