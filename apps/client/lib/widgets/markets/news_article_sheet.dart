import 'package:flutter/material.dart';

import '../../l10n/app_language.dart';
import '../../models/market_news_item.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

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
                AppText(
                  item.title,
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                AppText(
                  item.source,
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppText(
                  'The article opens in your browser. HNW does not host a full in-app news body.',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
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
                      child: const AppText('Open article'),
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
