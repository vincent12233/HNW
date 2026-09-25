import 'package:flutter/material.dart';

import '../../l10n/app_language.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/number_formatters.dart';
import '../app_card.dart';
import '../home/mini_line_chart_painter.dart';

class MarketsIndexCard extends StatelessWidget {
  const MarketsIndexCard({
    super.key,
    required this.label,
    required this.price,
    required this.changePercent,
    this.venue = 'NSE',
    this.history = const [],
    this.onTap,
  });

  final String label;
  final double price;
  final double changePercent;
  final String venue;
  final List<double> history;
  final VoidCallback? onTap;

  bool get available => price > 0 && price.isFinite && changePercent.isFinite;

  @override
  Widget build(BuildContext context) {
    final color = !available
        ? AppColors.neutral
        : changePercent > 0
        ? AppColors.gain
        : changePercent < 0
        ? AppColors.loss
        : AppColors.textSecondary;
    final signed = changePercent > 0
        ? '+${changePercent.toStringAsFixed(2)}%'
        : '${changePercent.toStringAsFixed(2)}%';
    return Semantics(
      button: onTap != null,
      label: label,
      child: AppCard(
        radius: AppRadius.md,
        padding: EdgeInsets.all(
          MediaQuery.sizeOf(context).width >= 360 &&
                  MediaQuery.textScalerOf(context).scale(1) <= 1.15
              ? AppSpacing.sm
              : AppSpacing.md,
        ),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: AppText(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelSmall.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSecondary,
                    borderRadius: AppRadius.borderSm,
                  ),
                  child: AppText(
                    venue,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textTertiary,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm - 2),
            AppText(
              available ? formatIndex(price) : '--',
              style: AppTypography.numericSmall.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Row(
              children: [
                Icon(
                  !available
                      ? Icons.schedule_rounded
                      : changePercent > 0
                      ? Icons.arrow_drop_up_rounded
                      : changePercent < 0
                      ? Icons.arrow_drop_down_rounded
                      : Icons.remove,
                  size: AppMotion.iconInline,
                  color: color,
                ),
                Expanded(
                  child: AppText(
                    available ? signed : 'Awaiting live quote',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelSmall.copyWith(
                      color: color,
                      fontWeight: FontWeight.w800,
                      fontFeatures: AppTypography.tabularFeatures,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm - 2),
            SizedBox(
              height: 24,
              width: double.infinity,
              child: available && history.length >= 2
                  ? ExcludeSemantics(
                      child: CustomPaint(
                        painter: MiniLineChartPainter(
                          color: color,
                          values: history,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
