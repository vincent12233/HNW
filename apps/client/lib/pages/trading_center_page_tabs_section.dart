part of 'trading_center_page.dart';

extension _TradingCenterTabsSection on _TradingCenterPageState {
  Widget _productTabs() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
    child: Row(
      children: [
        for (final item in <(int, String)>[
          (
            0,
            AppContentService.instance.current.text(
              'trading',
              'tab.all',
              fallback: 'Overview',
            ),
          ),
          (
            1,
            AppContentService.instance.current.text(
              'trading',
              'tab.ins_stock',
              fallback: 'Intr.',
            ),
          ),
          (
            5,
            AppContentService.instance.current.text(
              'trading',
              'tab.otc',
              fallback: 'OTC',
            ),
          ),
          (
            6,
            AppContentService.instance.current.text(
              'trading',
              'tab.ipo',
              fallback: 'IPO',
            ),
          ),
        ])
          Expanded(
            child: Semantics(
              selected:
                  selectedTab == item.$1 ||
                  (item.$1 == 0 && [2, 3, 4, 7].contains(selectedTab)),
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color:
                          selectedTab == item.$1 ||
                              (item.$1 == 0 &&
                                  [2, 3, 4, 7].contains(selectedTab))
                          ? AppColors.brandPrimary
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: TextButton(
                  onPressed: () => _selectTab(item.$1),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    minimumSize: const Size(0, 48),
                    foregroundColor:
                        selectedTab == item.$1 ||
                            (item.$1 == 0 && [2, 3, 4, 7].contains(selectedTab))
                        ? AppColors.brandPrimary
                        : AppColors.textSecondary,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.zero,
                    ),
                  ),
                  child: AppText(
                    item.$2,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: AppTypography.labelSmall.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );

}
