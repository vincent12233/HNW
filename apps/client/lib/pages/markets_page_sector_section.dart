part of 'markets_page.dart';

extension _MarketsSectorSection on _MarketsPageState {
  Widget _sectorBreakdown() {
    final groups = <String, List<StockQuote>>{};
    for (final stock in widget.stocks) {
      final category = stock.category?.trim();
      if (category == null || category.isEmpty) continue;
      groups.putIfAbsent(category, () => <StockQuote>[]).add(stock);
    }
    final rows = groups.entries.toList()
      ..sort((left, right) => right.value.length.compareTo(left.value.length));

    if (rows.isEmpty) {
      return AppCard(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Row(
          children: [
            const Icon(Icons.category_outlined, color: AppColors.textTertiary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: AppText(
                'Sector classifications are currently unavailable.',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(
          'Sector Constituents',
          style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: AppSpacing.md - 2),
        ...rows.take(12).map((row) {
          final symbols = row.value
              .map((stock) => stock.symbol)
              .take(4)
              .join(', ');
          return AppCard(
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(
                Icons.category_outlined,
                color: AppColors.brandPrimary,
              ),
              title: AppText(row.key, style: AppTypography.titleSmall),
              subtitle: AppText(
                symbols,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              trailing: AppText(
                '${row.value.length}',
                style: AppTypography.labelMedium,
              ),
            ),
          );
        }),
      ],
    );
  }
}