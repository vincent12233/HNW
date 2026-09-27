part of 'markets_page.dart';

extension _MarketsBannerSection on _MarketsPageState {
  Widget _marketBanner() {
    return ListenableBuilder(
      listenable: AppContentService.instance,
      builder: (context, _) {
        final content = AppContentService.instance.current;
        final title = content.text(
          'home',
          'markets.banner.title',
          fallback: 'Track live markets & place orders on the go',
        );
        final subtitle = content.text(
          'home',
          'markets.banner.subtitle',
          fallback: 'Live prices, company logos and secure execution',
        );
        return AppCard(
          radius: AppRadius.sm,
          backgroundColor: AppColors.brandPrimarySoft,
          bordered: false,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md + 2,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      title,
                      style: AppTypography.labelLarge.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    AppText(
                      subtitle,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              const Icon(
                Icons.candlestick_chart_rounded,
                color: AppColors.gain,
                size: 50,
              ),
            ],
          ),
        );
      },
    );
  }
}