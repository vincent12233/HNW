part of 'trading_center_page.dart';

extension _TradingCenterActionSection on _TradingCenterPageState {
  Widget _tradingShortcuts() {
    final items = <(int, String)>[
      (
        4,
        AppContentService.instance.current.text(
          'trading',
          'shortcut.orders',
          fallback: 'Orders',
        ),
      ),
      (
        3,
        AppContentService.instance.current.text(
          'trading',
          'tab.pending',
          fallback: 'Pending',
        ),
      ),
      (
        2,
        AppContentService.instance.current.text(
          'trading',
          'tab.holdings',
          fallback: 'Holdings',
        ),
      ),
      (
        7,
        AppContentService.instance.current.text(
          'trading',
          'tab.history',
          fallback: 'History',
        ),
      ),
    ];

    return SizedBox(
      height: 44,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.lg),
        itemBuilder: (context, index) {
          final item = items[index];
          final selected = selectedTab == item.$1;
          return Semantics(
            selected: selected,
            child: Tooltip(
              message: tr(tabs[item.$1].label),
              child: InkWell(
                key: ValueKey('trade-shortcut-${item.$1}'),
                onTap: () => _selectTab(item.$1),
                child: Container(
                  alignment: Alignment.center,
                  constraints: const BoxConstraints(minWidth: 56),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: selected
                            ? AppColors.brandPrimary
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                  child: AppText(
                    item.$2,
                    style: AppTypography.labelSmall.copyWith(
                      color: selected
                          ? AppColors.brandPrimary
                          : AppColors.textSecondary,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _balanceMetric(String label, double? value, {Color? valueColor}) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(
            label,
            style: AppTypography.caption.copyWith(
              color: AppColors.textInverse.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: AppText(
              value == null ? '--' : formatPrice(value),
              style: AppTypography.numericMedium.copyWith(
                color: valueColor ?? AppColors.textInverse,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      );

}
