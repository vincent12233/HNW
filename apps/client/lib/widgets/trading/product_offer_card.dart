import 'package:flutter/material.dart';
import '../../app_config.dart';
import '../../l10n/app_language.dart';
import '../stock_logo.dart';

/// Compact trading catalogue card. Price details belong in the trade dialog.
class ProductOfferCard extends StatelessWidget {
  const ProductOfferCard({super.key, required this.name, required this.symbol,
    required this.type, required this.marketPrice, required this.offerPrice,
    required this.onTrade, this.status, this.actionLabel = 'Trade Now',
    this.offerLabel = 'Offer Price'});

  final String name, symbol, type, actionLabel;
  final String? status;
  final double marketPrice, offerPrice;
  final String offerLabel;
  final VoidCallback? onTrade;

  @override
  Widget build(BuildContext context) {
    final valid = marketPrice > 0 && offerPrice > 0 &&
        marketPrice.isFinite && offerPrice.isFinite;
    final expected = valid ? (marketPrice - offerPrice) / offerPrice * 100 : null;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          StockLogo(symbol: symbol, size: 44),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(name, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 6, children: [
                AppText(symbol, style: const TextStyle(color: Colors.black54, fontSize: 12)),
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
                  child: AppText(type, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
                if (status != null) AppText(status!, style: const TextStyle(fontSize: 11, color: Colors.black54)),
              ]),
            ])),
        ]),
        const SizedBox(height: 24),
        AppText(expected == null ? '--' : '${expected.toStringAsFixed(2)}%',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800,
            color: (expected ?? 0) < 0 ? AppConfig.lossColor : AppConfig.gainColor)),
        const SizedBox(height: 4),
        const AppText('Expected return', style: TextStyle(fontSize: 12, color: Colors.black54)),
        const SizedBox(height: 16),
        Wrap(
          spacing: 18,
          runSpacing: 12,
          children: [
            _metric('Market Price', marketPrice),
            _metric(offerLabel, offerPrice),
            if (valid) _metric('Discount', marketPrice - offerPrice,
              color: AppConfig.gainColor),
          ],
        ),
        const SizedBox(height: 18),
        SizedBox(width: double.infinity, child: FilledButton(
          onPressed: onTrade, child: AppText(actionLabel))),
      ]),
    );
  }

  Widget _metric(String label, double value, {Color? color}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      AppText(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
      const SizedBox(height: 4),
      AppText('₹${value.toStringAsFixed(2)}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
    ],
  );
}
