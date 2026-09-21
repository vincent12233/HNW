import 'package:flutter/material.dart';

import '../l10n/app_language.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

Future<void> showRecordDetailSheet(
  BuildContext context, {
  required String title,
  required List<(String, String)> rows,
  Widget? status,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    shape: RoundedRectangleBorder(borderRadius: AppRadius.sheetTop()),
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.sm,
            AppSpacing.xl,
            AppSpacing.xxl,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: AppText(title, style: AppTypography.headline),
                    ),
                    IconButton(
                      tooltip: 'Close details',
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                if (status != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  status,
                ],
                const SizedBox(height: AppSpacing.lg),
                for (final row in rows) ...[
                  AppText(
                    row.$1,
                    style: AppTypography.caption.copyWith(
                      color: AppTypography.caption.color,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  AppText(
                    row.$2.isEmpty ? 'Unavailable' : row.$2,
                    style: AppTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );
}
