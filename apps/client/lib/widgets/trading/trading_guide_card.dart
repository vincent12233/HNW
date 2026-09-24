import '../../l10n/app_language.dart';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../app_card.dart';

class TradingGuideCard extends StatelessWidget {
  const TradingGuideCard({super.key, required this.body, this.title});

  final String? title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md + 2),
      backgroundColor: AppColors.surfaceInput,
      shadow: AppCardShadow.none,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null && title!.isNotEmpty) ...[
            AppText(
              title!,
              style: AppTypography.labelLarge.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
          ],
          AppText(body, style: AppTypography.bodySmall),
        ],
      ),
    );
  }
}
