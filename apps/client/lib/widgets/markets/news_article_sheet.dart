import 'package:flutter/material.dart';

import '../../l10n/app_language.dart';
import '../../models/market_news_item.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/number_formatters.dart';
import '../app_card.dart';

Future<void> showMarketNewsSheet({
  required BuildContext context,
  required MarketNewsItem item,
  required Future<void> Function(MarketNewsItem item) onOpen,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) {
      return SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.xxl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (item.imageUrl?.isNotEmpty == true) ...[
                  ClipRRect(
                    borderRadius: AppRadius.borderMd,
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Image.network(
                        item.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const ColoredBox(
                          color: AppColors.brandPrimarySoft,
                          child: Center(
                            child: Icon(
                              Icons.newspaper_outlined,
                              color: AppColors.brandPrimary,
                              size: 36,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                AppText(
                  item.title,
                  style: AppTypography.titleLarge.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Icon(
                      Icons.public_rounded,
                      size: 16,
                      color: AppColors.textTertiary,
                    ),
                    AppText(item.source, style: AppTypography.labelSmall),
                    AppText(
                      '· ${formatAppDateTime(item.publishedAt)}',
                      style: AppTypography.caption,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                AppCard(
                  backgroundColor: AppColors.surfaceInput,
                  shadow: AppCardShadow.none,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.open_in_browser_rounded,
                        color: AppColors.brandPrimary,
                        size: 20,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: AppText(
                          'The article opens in your browser. HNW does not host a full in-app news body.',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: Semantics(
                    button: true,
                    label: tr('Open article'),
                    child: FilledButton(
                      onPressed: () async {
                        Navigator.pop(sheetContext);
                        await onOpen(item);
                      },
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, AppSpacing.buttonHeight),
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.borderSm,
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.open_in_new_rounded, size: 18),
                          SizedBox(width: AppSpacing.sm),
                          AppText('Open article'),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
