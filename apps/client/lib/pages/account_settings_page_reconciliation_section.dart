part of 'account_settings_page.dart';

extension _AccountSettingsReconciliationSection on _AccountSettingsPageState {
  Widget _reconciliation() {
    final r = data is Map
        ? Map<String, dynamic>.from(data as Map)
        : <String, dynamic>{};
    final c = r['categories'] is Map
        ? Map<String, dynamic>.from(r['categories'] as Map)
        : <String, dynamic>{};
    return ListView(
      padding: AppSpacing.page,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppText('Total assets', style: AppTypography.caption),
              AppText(
                formatPriceValue(r['totalAssets']),
                style: AppTypography.titleMedium,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final e in c.entries) ...[
                AppText(e.key, style: AppTypography.caption),
                AppText(
                  formatPriceValue(e.value),
                  style: AppTypography.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              r['balanced'] == true
                  ? Icons.verified_outlined
                  : Icons.warning_amber_rounded,
              color: r['balanced'] == true ? AppColors.gain : AppColors.warning,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(
                    r['balanced'] == true
                        ? 'Account reconciled'
                        : 'Review required',
                  ),
                  AppText(
                    r['asOf'] == null || r['asOf'].toString().trim().isEmpty
                        ? 'Unavailable'
                        : 'As of ${r['asOf']}',
                    style: AppTypography.caption,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}