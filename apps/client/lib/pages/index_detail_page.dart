import 'package:flutter/material.dart';

import '../l10n/app_language.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app_card.dart';
import '../widgets/app_page_scaffold.dart';
import '../widgets/home/mini_line_chart_painter.dart';
import '../widgets/market_status_card.dart';
import '../widgets/markets/browse_only_banner.dart';
import '../widgets/markets/market_index_ref.dart';
import '../widgets/markets/markets_index_card.dart';
import '../widgets/stock_history_chart.dart';

class IndexDetailPage extends StatelessWidget {
  const IndexDetailPage({
    super.key,
    required this.quote,
    this.marketOpen,
    this.marketHours = '09:15 - 15:30 IST',
    this.quotesConnected,
  });

  final MarketIndexQuote quote;
  final bool? marketOpen;
  final String marketHours;
  final bool? quotesConnected;

  @override
  Widget build(BuildContext context) {
    final ref = quote.ref;
    final color = !quote.available
        ? AppColors.neutral
        : quote.changePercent >= 0
        ? AppColors.gain
        : AppColors.loss;
    return AppPageScaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText(ref.label),
            AppText(
              '${ref.exchange} · ${ref.symbol}',
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: ListView(
            padding: AppSpacing.page,
            children: [
              MarketStatusCard(
                isOpen: marketOpen,
                hours: marketHours,
                quotesConnected: quotesConnected,
              ),
              const SizedBox(height: AppSpacing.md),
              AppFadeIn(
                switchKey: ref.label,
                child: MarketsIndexCard(
                  label: ref.label,
                  price: quote.price,
                  changePercent: quote.changePercent,
                  venue: ref.venue,
                  history: quote.history,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              const BrowseOnlyBanner(productLabel: 'Index'),
              const SizedBox(height: AppSpacing.md),
              AppText(
                'Indices cannot be bought or sold in this app.',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (ref.supportsHistoryChart)
                StockHistoryChart(
                  symbol: ref.symbol,
                  exchange: ref.exchange,
                  latestPrice: quote.price,
                  latestAt: DateTime.now(),
                )
              else ...[
                AppCard(
                  radius: AppRadius.sm,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(
                        'Full history is unavailable',
                        style: AppTypography.titleSmall.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      AppText(
                        'The current market-data API serves OHLC history for NSE and BSE only. This global index can be reviewed, not charted as a tradable instrument.',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (quote.history.length >= 2) ...[
                        const SizedBox(height: AppSpacing.md),
                        SizedBox(
                          height: 120,
                          width: double.infinity,
                          child: CustomPaint(
                            painter: MiniLineChartPainter(
                              color: color,
                              values: quote.history,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
