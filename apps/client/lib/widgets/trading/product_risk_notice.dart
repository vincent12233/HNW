import 'package:flutter/material.dart';

import '../../l10n/app_language.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_typography.dart';

/// Shared product disclosure used by Institutional, OTC and IPO confirmations.
class ProductRiskNotice extends StatelessWidget {
  const ProductRiskNotice({super.key});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.brandPrimarySoft,
      borderRadius: AppRadius.borderMd,
    ),
    child: AppText(
      'Displayed prices and returns are references, not guaranteed outcomes. Review the product terms before confirming.',
      style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
    ),
  );
}
