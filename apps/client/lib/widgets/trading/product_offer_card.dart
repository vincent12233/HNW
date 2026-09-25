import 'package:flutter/material.dart';
import '../../l10n/app_language.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_typography.dart';
import '../app_card.dart';
import '../stock_logo.dart';

/// Compact trading catalogue card. Price details belong in the trade dialog.
class ProductOfferCard extends StatelessWidget {
  const ProductOfferCard({
    super.key,
    required this.name,
    required this.symbol,
    required this.type,
    required this.marketPrice,
    required this.offerPrice,
    required this.onTrade,
    this.status,
    this.actionLabel = 'Trade Now',
    this.offerLabel = 'Offer Price',
    this.expectedReturn,
  });

  final String name, symbol, type, actionLabel;
  final String? status;
  final double marketPrice, offerPrice;
  final String offerLabel;

  /// When set, shown instead of (market − offer) / offer.
  final double? expectedReturn;
  final VoidCallback? onTrade;

  @override
  Widget build(BuildContext context) {
    final valid =
        marketPrice > 0 &&
        offerPrice > 0 &&
        marketPrice.isFinite &&
        offerPrice.isFinite;
    // Prefer admin/CMS expectedReturn. Only derive from price spread when the
    // offer differs from market (e.g. OTC). Equal live prices must not show 0%.
    final expected = expectedReturn != null && expectedReturn!.isFinite
        ? expectedReturn
        : valid && (marketPrice - offerPrice).abs() > 1e-9
        ? (marketPrice - offerPrice) / offerPrice * 100
        : null;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      radius: AppRadius.md,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StockLogo(symbol: symbol, size: 38),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        AppText(symbol, style: AppTypography.caption),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.brandPrimarySoft,
                            borderRadius: AppRadius.borderSm,
                          ),
                          child: AppText(
                            type,
                            style: AppTypography.labelSmall.copyWith(
                              color: AppColors.brandPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (status != null)
                          AppText(status!, style: AppTypography.caption),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: (expected ?? 0) < 0
                        ? AppColors.lossSoft
                        : const Color(0xFF10B981),
                    borderRadius: AppRadius.borderSm,
                  ),
                  child: AppText(
                    expected == null ? '--' : '${expected.toStringAsFixed(2)}%',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textInverse,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Flexible(
                child: AppText(
                  'Expected\nreturn',
                  style: AppTypography.caption,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brandPrimary,
                minimumSize: const Size.fromHeight(40),
                shape: const StadiumBorder(),
              ),
              onPressed: onTrade,
              child: AppText(actionLabel),
            ),
          ),
        ],
      ),
    );
  }
}
