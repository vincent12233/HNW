import 'package:flutter/material.dart';
import '../../app_config.dart';
import '../../l10n/app_language.dart';
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
    final expected = expectedReturn != null && expectedReturn!.isFinite
        ? expectedReturn
        : valid
            ? (marketPrice - offerPrice) / offerPrice * 100
            : null;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StockLogo(symbol: symbol, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        AppText(
                          symbol,
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 12,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: AppText(
                            type,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (status != null)
                          AppText(
                            status!,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.black54,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: (expected ?? 0) < 0
                      ? const Color(0xFFFEE2E2)
                      : const Color(0xFF10B981),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: AppText(
                  expected == null ? '--' : '${expected.toStringAsFixed(2)}%',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: (expected ?? 0) < 0
                        ? AppConfig.lossColor
                        : Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const AppText(
                'Expected\nreturn',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.black54,
                  height: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onTrade,
              child: AppText(actionLabel),
            ),
          ),
        ],
      ),
    );
  }
}
