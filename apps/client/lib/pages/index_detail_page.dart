import 'package:flutter/material.dart';

import '../l10n/app_language.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/number_formatters.dart';
import '../widgets/app_card.dart';
import '../widgets/app_page_scaffold.dart';
import '../widgets/home/mini_line_chart_painter.dart';
import '../widgets/market_status_card.dart';
import '../widgets/markets/browse_only_banner.dart';
import '../widgets/markets/market_index_ref.dart';
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
          child: SingleChildScrollView(
            padding: AppSpacing.page,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MarketStatusCard(
                  isOpen: marketOpen,
                  hours: marketHours,
                  quotesConnected: quotesConnected,
                ),
                const SizedBox(height: AppSpacing.md),
                AppFadeIn(
                  switchKey: ref.label,
                  child: _IndexHero(quote: quote),
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
      ),
    );
  }
}

class _IndexHero extends StatelessWidget {
  const _IndexHero({required this.quote});

  final MarketIndexQuote quote;

  @override
  Widget build(BuildContext context) {
    final available = quote.available;
    final positive = quote.changePercent >= 0;
    final changeColor = !available
        ? AppColors.textInverse.withValues(alpha: 0.72)
        : positive
        ? AppColors.chartGain
        : AppColors.lossSoft;
    final muted = AppColors.textInverse.withValues(alpha: 0.72);
    final signedChange = positive
        ? '+${quote.changePercent.toStringAsFixed(2)}%'
        : '${quote.changePercent.toStringAsFixed(2)}%';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.brandPrimary, AppColors.brandGradientEnd],
        ),
        borderRadius: AppRadius.borderMd,
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      quote.ref.label,
                      style: AppTypography.titleMedium.copyWith(
                        color: AppColors.textInverse,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    AppText(
                      '${quote.ref.venue} · ${quote.ref.symbol}',
                      style: AppTypography.caption.copyWith(color: muted),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: AppRadius.borderSm,
                ),
                child: AppText(
                  available ? 'LIVE INDEX' : 'AWAITING DATA',
                  style: AppTypography.caption.copyWith(
                    color: available ? AppColors.chartGain : muted,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          AppText(
            available ? formatIndex(quote.price) : '--',
            style: AppTypography.numericInverse.copyWith(fontSize: 30),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Icon(
                !available
                    ? Icons.remove
                    : positive
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
                size: AppMotion.iconInline,
                color: changeColor,
              ),
              const SizedBox(width: AppSpacing.xs),
              AppText(
                available ? signedChange : 'Index quote unavailable',
                style: AppTypography.labelLarge.copyWith(
                  color: changeColor,
                  fontWeight: FontWeight.w800,
                  fontFeatures: AppTypography.tabularFeatures,
                ),
              ),
            ],
          ),
          if (available && quote.history.length >= 2) ...[
            const SizedBox(height: AppSpacing.lg),
            ExcludeSemantics(
              child: SizedBox(
                height: 56,
                width: double.infinity,
                child: CustomPaint(
                  painter: MiniLineChartPainter(
                    color: changeColor,
                    values: quote.history,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
