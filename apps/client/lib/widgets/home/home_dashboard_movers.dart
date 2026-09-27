part of 'home_dashboard.dart';

class _MoversSection extends StatelessWidget {
  const _MoversSection({
    required this.gainers,
    required this.losers,
    required this.tab,
    required this.onTab,
    required this.onOpen,
    required this.onViewAll,
    this.onLogoLoadFailed,
  });

  final List<StockQuote> gainers;
  final List<StockQuote> losers;
  final int tab;
  final ValueChanged<int> onTab;
  final ValueChanged<StockQuote> onOpen;
  final VoidCallback onViewAll;
  final VoidCallback? onLogoLoadFailed;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked =
            constraints.maxWidth < 300 ||
            MediaQuery.textScalerOf(context).scale(1) > 1.5;
        if (stacked) {
          return Column(
            children: [
              Row(
                children: [
                  _MoverTab(
                    label: 'Top Gainers',
                    selected: tab == 0,
                    onTap: () => onTab(0),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _MoverTab(
                    label: 'Top Losers',
                    selected: tab == 1,
                    onTap: () => onTab(1),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              _MoverList(
                title: tab == 0 ? 'Top Gainers' : 'Top Losers',
                items: tab == 0 ? gainers : losers,
                positive: tab == 0,
                onOpen: onOpen,
                onViewAll: onViewAll,
                onLogoLoadFailed: onLogoLoadFailed,
                showHeader: false,
              ),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _MoverList(
                title: 'Top Gainers',
                items: gainers,
                positive: true,
                onOpen: onOpen,
                onViewAll: onViewAll,
                onLogoLoadFailed: onLogoLoadFailed,
              ),
            ),
            const SizedBox(width: AppSpacing.sm + 2),
            Expanded(
              child: _MoverList(
                title: 'Top Losers',
                items: losers,
                positive: false,
                onOpen: onOpen,
                onViewAll: onViewAll,
                onLogoLoadFailed: onLogoLoadFailed,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MoverTab extends StatelessWidget {
  const _MoverTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: Material(
          color: selected ? AppColors.brandPrimarySoft : AppColors.surface,
          borderRadius: AppRadius.borderSm,
          child: InkWell(
            onTap: onTap,
            borderRadius: AppRadius.borderSm,
            child: Container(
              alignment: Alignment.center,
              constraints: const BoxConstraints(minHeight: AppMotion.tapTarget),
              decoration: BoxDecoration(
                borderRadius: AppRadius.borderSm,
                border: Border.all(
                  color: selected ? AppColors.brandPrimary : AppColors.border,
                ),
              ),
              child: AppText(
                label,
                style: AppTypography.labelSmall.copyWith(
                  color: selected
                      ? AppColors.brandPrimary
                      : AppColors.textSecondary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MoverList extends StatelessWidget {
  const _MoverList({
    required this.title,
    required this.items,
    required this.positive,
    required this.onOpen,
    required this.onViewAll,
    this.onLogoLoadFailed,
    this.showHeader = true,
  });

  final String title;
  final List<StockQuote> items;
  final bool positive;
  final ValueChanged<StockQuote> onOpen;
  final VoidCallback onViewAll;
  final VoidCallback? onLogoLoadFailed;
  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    final color = positive ? AppColors.gain : AppColors.loss;
    return AppCard(
      radius: AppRadius.sm,
      padding: AppSpacing.card.copyWith(
        top: AppSpacing.md,
        bottom: AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showHeader)
            Row(
              children: [
                Expanded(
                  child: AppText(
                    title,
                    style: AppTypography.labelMedium.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    minimumSize: const Size(
                      AppMotion.tapTarget,
                      AppMotion.tapTarget,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                    ),
                  ),
                  onPressed: onViewAll,
                  child: AppText(
                    'View All',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.brandPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: AppText(
                positive ? 'No gainers right now' : 'No losers right now',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ),
          for (final stock in items.take(3))
            InkWell(
              onTap: () => onOpen(stock),
              child: Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm + 1),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final quote = Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        AppText(
                          formatPrice(stock.price),
                          maxLines: 2,
                          textAlign: TextAlign.right,
                          style: AppTypography.numericSmall.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Wrap(
                          alignment: WrapAlignment.end,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Icon(
                              stock.change > 0
                                  ? Icons.arrow_drop_up_rounded
                                  : Icons.arrow_drop_down_rounded,
                              size: 16,
                              color: color,
                            ),
                            AppText(
                              '${stock.change > 0 ? '+' : ''}${stock.change.toStringAsFixed(2)}%',
                              style: AppTypography.labelSmall.copyWith(
                                color: color,
                                fontWeight: FontWeight.w800,
                                fontFeatures: AppTypography.tabularFeatures,
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                    return Row(
                      children: [
                        StockLogo(
                          symbol: stock.symbol,
                          logoUrl: stock.logoUrl,
                          size: 22,
                          onLoadFailed: onLogoLoadFailed,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AppText(
                                stock.name.isNotEmpty
                                    ? stock.name
                                    : stock.symbol,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.labelSmall.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              AppText(
                                stock.symbol,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.caption.copyWith(
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: (constraints.maxWidth * 0.46).clamp(
                              72,
                              140,
                            ),
                          ),
                          child: quote,
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}
