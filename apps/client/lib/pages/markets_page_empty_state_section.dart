part of 'markets_page.dart';

extension _MarketsEmptyStateSection on _MarketsPageState {
  Widget _emptyState(IconData icon, String title, String subtitle) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.xxxl),
      children: [
        const SizedBox(height: 100),
        Icon(icon, size: 64, color: AppColors.textTertiary),
        const SizedBox(height: AppSpacing.lg),
        AppText(
          title,
          textAlign: TextAlign.center,
          style: AppTypography.headline.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppText(
          subtitle,
          textAlign: TextAlign.center,
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.lg + 2),
        Center(
          child: OutlinedButton.icon(
            onPressed: _searchLoading ? null : _refreshAll,
            icon: _searchLoading
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      semanticsLabel: 'Refreshing market data',
                    ),
                  )
                : const Icon(Icons.refresh_rounded, size: 18),
            label: AppText(
              _marketCopy('markets.refresh', 'Refresh market data'),
            ),
          ),
        ),
      ],
    );
  }
}