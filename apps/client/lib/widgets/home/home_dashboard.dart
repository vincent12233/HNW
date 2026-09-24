import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../l10n/app_language.dart';
import '../../models/market_news_item.dart';
import '../../models/stock_quote.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_shadows.dart';
import '../../theme/app_typography.dart';
import '../../utils/number_formatters.dart';
import '../account_metrics.dart';
import '../app_card.dart';
import '../market_header.dart';
import '../market_status_card.dart';
import '../stock_list_tile.dart';
import '../stock_logo.dart';
import 'home_action_button.dart';
import 'home_dashboard_data.dart';
import 'home_kyc_todo.dart';
import 'mini_line_chart_painter.dart';

class HomeDashboard extends StatefulWidget {
  const HomeDashboard({
    super.key,
    required this.accountName,
    required this.totalAssets,
    required this.availableFunds,
    required this.frozenFunds,
    required this.todayPnl,
    required this.accountLoaded,
    required this.accountFailed,
    required this.accountRefreshing,
    required this.quotesLoading,
    required this.marketOpen,
    required this.marketHours,
    required this.quotesConnected,
    required this.indices,
    required this.gainers,
    required this.losers,
    required this.news,
    required this.onSearch,
    required this.onNotifications,
    required this.onToggleHideBalances,
    required this.onDeposit,
    required this.onWithdraw,
    required this.onTrade,
    required this.onRetryAccount,
    required this.onRetryNews,
    required this.onRetryQuotes,
    required this.onOpenMarkets,
    required this.onOpenNews,
    required this.onOpenStock,
    this.onOpenIndex,
    this.featured = const [],
    this.kycStatus = 'UNKNOWN',
    this.kycAvailable = false,
    this.hideBalances = false,
    this.periodProfit,
    this.periodLabel = '1D',
    this.periodLoading = false,
    this.historyError,
    this.historyFrom,
    this.portfolioSeries = const [],
    this.outstandingIpo = 0,
    this.quoteUpdatedAt,
    this.quotesStale = false,
    this.notificationCount = 0,
    this.avatarBytes,
    this.onAvatarTap,
    this.onSelectPeriod,
    this.onOpenKyc,
    this.onViewAllNews,
    this.onLogoLoadFailed,
    this.announcement,
    this.companyCard,
    this.bottomPadding = AppSpacing.xxl,
    this.unrealizedPnl,
  });

  final String accountName;
  final double totalAssets;
  final double availableFunds;
  final double frozenFunds;
  final double todayPnl;
  final double? unrealizedPnl;
  final bool accountLoaded;
  final bool accountFailed;
  final bool accountRefreshing;
  final bool quotesLoading;
  final bool? marketOpen;
  final String marketHours;
  final bool quotesConnected;
  final List<HomeIndexQuote> indices;
  final List<StockQuote> gainers;
  final List<StockQuote> losers;
  final List<MarketNewsItem> news;
  final List<StockQuote> featured;
  final String kycStatus;
  final bool kycAvailable;
  final bool hideBalances;
  final double? periodProfit;
  final String periodLabel;
  final bool periodLoading;
  final String? historyError;
  final String? historyFrom;
  final List<double> portfolioSeries;
  final double outstandingIpo;
  final DateTime? quoteUpdatedAt;
  final bool quotesStale;
  final int notificationCount;
  final Uint8List? avatarBytes;
  final VoidCallback? onAvatarTap;
  final VoidCallback onSearch;
  final VoidCallback onNotifications;
  final VoidCallback onToggleHideBalances;
  final VoidCallback onDeposit;
  final VoidCallback onWithdraw;
  final VoidCallback onTrade;
  final VoidCallback onRetryAccount;
  final VoidCallback onRetryNews;
  final VoidCallback onRetryQuotes;
  final VoidCallback onOpenMarkets;
  final ValueChanged<MarketNewsItem> onOpenNews;
  final ValueChanged<StockQuote> onOpenStock;
  final ValueChanged<HomeIndexQuote>? onOpenIndex;
  final ValueChanged<String>? onSelectPeriod;
  final VoidCallback? onOpenKyc;
  final VoidCallback? onViewAllNews;
  final VoidCallback? onLogoLoadFailed;
  final Widget? announcement;
  final Widget? companyCard;
  final double bottomPadding;

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> {
  int _moverTab = 0;

  String _money(double value, {bool signed = false}) {
    if (widget.hideBalances) return '******';
    if (!widget.accountLoaded) return '--';
    return signed ? formatSignedPrice(value) : formatPrice(value);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final horizontal = size.width < 360 ? AppSpacing.md + 2 : AppSpacing.lg;
    final tabletSide = size.width >= 768 ? (size.width - 720) / 2 : horizontal;
    final side = tabletSide < horizontal ? horizontal : tabletSide;
    final kyc = homeKycTodo(widget.kycStatus, available: widget.kycAvailable);
    final freshness = homeQuoteFreshnessLabel(
      updatedAt: widget.quoteUpdatedAt,
      quotesConnected: widget.quotesConnected,
      stale: widget.quotesStale,
    );
    final loading = widget.quotesLoading && !widget.accountLoaded;

    return SingleChildScrollView(
      key: const PageStorageKey('home-dashboard'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        side,
        AppSpacing.md + 2,
        side,
        widget.bottomPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.quotesLoading || widget.accountRefreshing)
            const Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.sm),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          MarketHeader(
            accountName: widget.accountName,
            avatarBytes: widget.avatarBytes,
            onAvatarTap: widget.onAvatarTap,
            onSearchTap: widget.onSearch,
            onNotificationTap: widget.onNotifications,
            notificationCount: widget.notificationCount,
          ),
          const SizedBox(height: AppSpacing.sm + 2),
          MarketStatusCard(
            isOpen: widget.marketOpen,
            hours: widget.marketHours,
            quotesConnected: widget.quotesConnected,
          ),
          if (widget.announcement != null) ...[
            const SizedBox(height: AppSpacing.sm + 2),
            widget.announcement!,
          ],
          if (kyc != HomeKycTodo.hidden && widget.onOpenKyc != null) ...[
            const SizedBox(height: AppSpacing.sm + 2),
            HomeKycTodoCard(todo: kyc, onOpen: widget.onOpenKyc!),
          ],
          const SizedBox(height: AppSpacing.md + 2),
          AppFadeIn(
            switchKey: loading ? 'loading' : 'ready',
            child: loading
                ? const _HomeSkeleton()
                : _AssetPanel(dashboard: widget, money: _money),
          ),
          if (!loading) ...[
            const SizedBox(height: AppSpacing.sm),
            _HomeQuickActions(dashboard: widget),
            AccountDataStatus(
              hasData: widget.accountLoaded,
              refreshing: widget.accountRefreshing,
              failed: widget.accountFailed,
              onRetry: widget.onRetryAccount,
            ),
            AppCard(
              radius: AppRadius.sm,
              child: AccountMetrics(
                items: [
                  AccountMetric(
                    'Available Funds',
                    _money(widget.availableFunds),
                  ),
                  AccountMetric('Frozen Funds', _money(widget.frozenFunds)),
                  AccountMetric(
                    "Today's P&L",
                    _money(widget.todayPnl, signed: true),
                    color: widget.hideBalances || !widget.accountLoaded
                        ? AppColors.textPrimary
                        : AppUiGainLoss.color(widget.todayPnl),
                  ),
                  if (widget.unrealizedPnl != null)
                    AccountMetric(
                      'Unrealized P&L',
                      _money(widget.unrealizedPnl!, signed: true),
                      color: widget.hideBalances || !widget.accountLoaded
                          ? AppColors.textPrimary
                          : AppUiGainLoss.color(widget.unrealizedPnl!),
                    ),
                ],
              ),
            ),
            if (widget.featured.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xl - 2),
              const _SectionTitle('Featured'),
              const SizedBox(height: AppSpacing.sm + 2),
              _FeaturedList(
                stocks: widget.featured,
                onOpen: widget.onOpenStock,
              ),
            ],
            const SizedBox(height: AppSpacing.xl - 2),
            _SectionTitle('Market Indices', onViewAll: widget.onOpenMarkets),
            const SizedBox(height: AppSpacing.sm + 2),
            _IndicesGrid(
              indices: widget.indices,
              onRetry: widget.onRetryQuotes,
              onOpenIndex: widget.onOpenIndex,
            ),
            const SizedBox(height: AppSpacing.xs),
            AppText(
              freshness,
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xl - 2),
            _MoversSection(
              gainers: widget.gainers,
              losers: widget.losers,
              tab: _moverTab,
              onTab: (tab) => setState(() => _moverTab = tab),
              onOpen: widget.onOpenStock,
              onViewAll: widget.onOpenMarkets,
              onLogoLoadFailed: widget.onLogoLoadFailed,
            ),
            const SizedBox(height: AppSpacing.xl - 2),
            _SectionTitle(
              'Market News',
              onViewAll: widget.news.isEmpty ? null : widget.onViewAllNews,
            ),
            const SizedBox(height: AppSpacing.sm + 2),
            _NewsSection(
              news: widget.news,
              onOpen: widget.onOpenNews,
              onRetry: widget.onRetryNews,
            ),
            if (widget.companyCard != null) ...[
              const SizedBox(height: AppSpacing.xl - 2),
              const _SectionTitle('Our Company'),
              const SizedBox(height: AppSpacing.sm + 2),
              widget.companyCard!,
            ],
            const SizedBox(height: AppSpacing.md + 2),
            _TradeEntry(onTap: widget.onTrade),
          ],
        ],
      ),
    );
  }
}

class AppUiGainLoss {
  static Color color(double value) {
    if (value == 0) return AppColors.textSecondary;
    return value > 0 ? AppColors.gain : AppColors.loss;
  }
}

class _AssetPanel extends StatelessWidget {
  const _AssetPanel({required this.dashboard, required this.money});

  final HomeDashboard dashboard;
  final String Function(double value, {bool signed}) money;

  @override
  Widget build(BuildContext context) {
    final pnl = dashboard.periodProfit;
    final inverseMuted = AppColors.textInverse.withValues(alpha: 0.72);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.brandPrimary, AppColors.brandGradientEnd],
        ),
        borderRadius: AppRadius.borderMd,
        boxShadow: AppShadows.brandHero,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: AppText(
                  'Total Portfolio Value',
                  style: AppTypography.labelLarge.copyWith(color: inverseMuted),
                ),
              ),
              IconButton(
                tooltip: tr(
                  dashboard.hideBalances ? 'Show balances' : 'Hide balances',
                ),
                onPressed: dashboard.onToggleHideBalances,
                icon: Icon(
                  dashboard.hideBalances
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: inverseMuted,
                  size: AppMotion.iconField,
                ),
              ),
              if (dashboard.onSelectPeriod != null)
                PopupMenuButton<String>(
                  tooltip: tr('Profit period'),
                  onSelected: dashboard.onSelectPeriod,
                  itemBuilder: (_) => ['1D', '1W', '1M', '3M', '1Y', 'All']
                      .map(
                        (period) => PopupMenuItem(
                          value: period,
                          child: AppText(period),
                        ),
                      )
                      .toList(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                      vertical: AppSpacing.sm,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppText(
                          dashboard.periodLabel,
                          style: AppTypography.labelMedium.copyWith(
                            color: AppColors.textInverse,
                          ),
                        ),
                        const Icon(
                          Icons.expand_more,
                          color: AppColors.textInverse,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          AppStatusSwitch(
            switchKey: dashboard.hideBalances
                ? 'hidden'
                : dashboard.accountLoaded
                ? 'loaded'
                : 'empty',
            child: AppText(
              money(dashboard.totalAssets),
              style: AppTypography.numericInverse.copyWith(fontSize: 26),
            ),
          ),
          if (!dashboard.hideBalances && dashboard.portfolioSeries.length >= 2)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: ExcludeSemantics(
                child: SizedBox(
                  width: double.infinity,
                  height: 36,
                  child: CustomPaint(
                    painter: MiniLineChartPainter(
                      color: (pnl ?? 0) < 0
                          ? AppColors.lossSoft
                          : AppColors.chartGain,
                      values: dashboard.portfolioSeries,
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          AppText(
            dashboard.hideBalances
                ? '******'
                : dashboard.periodLoading
                ? 'Loading returns...'
                : pnl == null
                ? 'Insufficient history'
                : '${formatPrice(pnl)} · ${dashboard.periodLabel}',
            style: AppTypography.labelLarge.copyWith(
              color: dashboard.hideBalances || (pnl ?? 0) == 0
                  ? inverseMuted
                  : (pnl ?? 0) > 0
                  ? AppColors.chartGain
                  : const Color(0xFFFCA5A5),
              fontWeight: FontWeight.w700,
              fontFeatures: AppTypography.tabularFeatures,
            ),
          ),
          if (dashboard.historyError != null)
            AppText(
              dashboard.historyError!,
              style: AppTypography.caption.copyWith(color: inverseMuted),
            ),
          if (dashboard.historyFrom != null && !dashboard.hideBalances)
            AppText(
              'Since ${dashboard.historyFrom}',
              style: AppTypography.caption.copyWith(color: inverseMuted),
            ),
          if (dashboard.outstandingIpo > 0) ...[
            const SizedBox(height: AppSpacing.sm),
            AppText(
              dashboard.hideBalances
                  ? '******'
                  : 'IPO Funds Required ${formatPrice(dashboard.outstandingIpo)}',
              style: AppTypography.labelSmall.copyWith(color: inverseMuted),
            ),
          ],
        ],
      ),
    );
  }
}

class _HomeQuickActions extends StatelessWidget {
  const _HomeQuickActions({required this.dashboard});

  final HomeDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    final actions = <Widget>[
      HomeActionButton(
        label: 'Add Money',
        subtitle: 'Instant Deposit',
        icon: Icons.add_card_outlined,
        color: AppColors.brandPrimary,
        onTap: dashboard.onDeposit,
      ),
      HomeActionButton(
        label: 'Withdraw',
        subtitle: 'Withdraw to Bank',
        icon: Icons.account_balance_outlined,
        color: AppColors.gain,
        onTap: dashboard.onWithdraw,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
        final columns = constraints.maxWidth >= 280 * scale ? 2 : 1;
        final width =
            (constraints.maxWidth - AppSpacing.sm * (columns - 1)) / columns;
        return Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final action in actions) SizedBox(width: width, child: action),
          ],
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.onViewAll});

  final String title;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: AppText(title, style: AppTypography.sectionTitle)),
        if (onViewAll != null)
          TextButton(
            style: TextButton.styleFrom(
              minimumSize: const Size(AppMotion.tapTarget, AppMotion.tapTarget),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            ),
            onPressed: onViewAll,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppText(
                  'View All',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.brandPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: AppSpacing.xxs),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 17,
                  color: AppColors.brandPrimary,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _IndicesGrid extends StatelessWidget {
  const _IndicesGrid({
    required this.indices,
    required this.onRetry,
    this.onOpenIndex,
  });

  final List<HomeIndexQuote> indices;
  final VoidCallback onRetry;
  final ValueChanged<HomeIndexQuote>? onOpenIndex;

  @override
  Widget build(BuildContext context) {
    final available = indices.where((item) => item.available).toList();
    if (indices.isEmpty || available.isEmpty) {
      return AppCard(
        radius: AppRadius.sm,
        child: Row(
          children: [
            const Icon(Icons.show_chart_rounded, color: AppColors.textTertiary),
            const SizedBox(width: AppSpacing.md),
            const Expanded(
              child: AppText(
                'Index quotes are unavailable.',
                style: AppTypography.bodySmall,
              ),
            ),
            IconButton(
              tooltip: tr('Retry quotes'),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
        final columns = constraints.maxWidth >= 520
            ? 4
            : constraints.maxWidth < 300 ||
                  scale > 1.2 && constraints.maxWidth < 360
            ? 1
            : 2;
        final width =
            (constraints.maxWidth - AppSpacing.sm * (columns - 1)) / columns;
        return Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final item in indices)
              SizedBox(
                width: width.clamp(
                  0,
                  columns == 1 ? constraints.maxWidth : 168,
                ),
                child: _IndexChip(item: item, onOpen: onOpenIndex),
              ),
          ],
        );
      },
    );
  }
}

class _IndexChip extends StatelessWidget {
  const _IndexChip({required this.item, this.onOpen});

  final HomeIndexQuote item;
  final ValueChanged<HomeIndexQuote>? onOpen;

  @override
  Widget build(BuildContext context) {
    final color = !item.available
        ? AppColors.neutral
        : AppUiGainLoss.color(item.changePercent);
    final signed = item.changePercent > 0
        ? '+${item.changePercent.toStringAsFixed(2)}%'
        : '${item.changePercent.toStringAsFixed(2)}%';
    return Semantics(
      button: onOpen != null,
      label: item.label,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppMotion.tapTarget),
        child: AppCard(
          radius: AppRadius.sm,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm + 2,
            AppSpacing.md,
            AppSpacing.sm + 2,
          ),
          onTap: onOpen == null ? null : () => onOpen!(item),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textTertiary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              AppText(
                item.available ? formatIndex(item.price) : '--',
                style: AppTypography.numericSmall.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Row(
                children: [
                  Icon(
                    !item.available
                        ? Icons.remove
                        : item.changePercent > 0
                        ? Icons.arrow_drop_up_rounded
                        : item.changePercent < 0
                        ? Icons.arrow_drop_down_rounded
                        : Icons.remove,
                    size: 18,
                    color: color,
                  ),
                  Expanded(
                    child: AppText(
                      item.available ? signed : 'Unavailable',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.labelSmall.copyWith(
                        color: color,
                        fontWeight: FontWeight.w800,
                        fontFeatures: AppTypography.tabularFeatures,
                      ),
                    ),
                  ),
                  if (item.available && item.history.length >= 2) ...[
                    const SizedBox(width: AppSpacing.sm),
                    ExcludeSemantics(
                      child: SizedBox(
                        key: ValueKey<String>('home-index-chart-${item.label}'),
                        width: 56,
                        height: 24,
                        child: CustomPaint(
                          painter: MiniLineChartPainter(
                            color: color,
                            values: item.history,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoversSection extends StatelessWidget {
  const _MoversSection({
    required this.gainers,
    required this.losers,
    required this.tab,
    required this.onTab,
    required this.onOpen,
    required this.onViewAll,
    this.onLogoLoadFailed,
  });

  final List<StockQuote> gainers;
  final List<StockQuote> losers;
  final int tab;
  final ValueChanged<int> onTab;
  final ValueChanged<StockQuote> onOpen;
  final VoidCallback onViewAll;
  final VoidCallback? onLogoLoadFailed;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 300;
        if (stacked) {
          return Column(
            children: [
              Row(
                children: [
                  _MoverTab(
                    label: 'Top Gainers',
                    selected: tab == 0,
                    onTap: () => onTab(0),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _MoverTab(
                    label: 'Top Losers',
                    selected: tab == 1,
                    onTap: () => onTab(1),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              _MoverList(
                title: tab == 0 ? 'Top Gainers' : 'Top Losers',
                items: tab == 0 ? gainers : losers,
                positive: tab == 0,
                onOpen: onOpen,
                onViewAll: onViewAll,
                onLogoLoadFailed: onLogoLoadFailed,
                showHeader: false,
              ),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _MoverList(
                title: 'Top Gainers',
                items: gainers,
                positive: true,
                onOpen: onOpen,
                onViewAll: onViewAll,
                onLogoLoadFailed: onLogoLoadFailed,
              ),
            ),
            const SizedBox(width: AppSpacing.sm + 2),
            Expanded(
              child: _MoverList(
                title: 'Top Losers',
                items: losers,
                positive: false,
                onOpen: onOpen,
                onViewAll: onViewAll,
                onLogoLoadFailed: onLogoLoadFailed,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MoverTab extends StatelessWidget {
  const _MoverTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: Material(
          color: selected ? AppColors.brandPrimarySoft : AppColors.surface,
          borderRadius: AppRadius.borderSm,
          child: InkWell(
            onTap: onTap,
            borderRadius: AppRadius.borderSm,
            child: Container(
              alignment: Alignment.center,
              constraints: const BoxConstraints(minHeight: AppMotion.tapTarget),
              decoration: BoxDecoration(
                borderRadius: AppRadius.borderSm,
                border: Border.all(
                  color: selected ? AppColors.brandPrimary : AppColors.border,
                ),
              ),
              child: AppText(
                label,
                style: AppTypography.labelSmall.copyWith(
                  color: selected
                      ? AppColors.brandPrimary
                      : AppColors.textSecondary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MoverList extends StatelessWidget {
  const _MoverList({
    required this.title,
    required this.items,
    required this.positive,
    required this.onOpen,
    required this.onViewAll,
    this.onLogoLoadFailed,
    this.showHeader = true,
  });

  final String title;
  final List<StockQuote> items;
  final bool positive;
  final ValueChanged<StockQuote> onOpen;
  final VoidCallback onViewAll;
  final VoidCallback? onLogoLoadFailed;
  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    final color = positive ? AppColors.gain : AppColors.loss;
    return AppCard(
      radius: AppRadius.sm,
      padding: AppSpacing.card.copyWith(
        top: AppSpacing.md,
        bottom: AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showHeader)
            Row(
              children: [
                Expanded(
                  child: AppText(
                    title,
                    style: AppTypography.labelMedium.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    minimumSize: const Size(
                      AppMotion.tapTarget,
                      AppMotion.tapTarget,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                    ),
                  ),
                  onPressed: onViewAll,
                  child: AppText(
                    'View All',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.brandPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: AppText(
                positive ? 'No gainers right now' : 'No losers right now',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ),
          for (final stock in items.take(3))
            InkWell(
              onTap: () => onOpen(stock),
              child: Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm + 1),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final quote = Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        AppText(
                          formatPrice(stock.price),
                          maxLines: 2,
                          textAlign: TextAlign.right,
                          style: AppTypography.numericSmall.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Wrap(
                          alignment: WrapAlignment.end,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Icon(
                              stock.change > 0
                                  ? Icons.arrow_drop_up_rounded
                                  : Icons.arrow_drop_down_rounded,
                              size: 16,
                              color: color,
                            ),
                            AppText(
                              '${stock.change > 0 ? '+' : ''}${stock.change.toStringAsFixed(2)}%',
                              style: AppTypography.labelSmall.copyWith(
                                color: color,
                                fontWeight: FontWeight.w800,
                                fontFeatures: AppTypography.tabularFeatures,
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                    return Row(
                      children: [
                        StockLogo(
                          symbol: stock.symbol,
                          logoUrl: stock.logoUrl,
                          size: 22,
                          onLoadFailed: onLogoLoadFailed,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AppText(
                                stock.name.isNotEmpty
                                    ? stock.name
                                    : stock.symbol,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.labelSmall.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              AppText(
                                stock.symbol,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.caption.copyWith(
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: (constraints.maxWidth * 0.46).clamp(
                              72,
                              140,
                            ),
                          ),
                          child: quote,
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FeaturedList extends StatelessWidget {
  const _FeaturedList({required this.stocks, required this.onOpen});

  final List<StockQuote> stocks;
  final ValueChanged<StockQuote> onOpen;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: AppRadius.sm,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var index = 0; index < stocks.length && index < 8; index++) ...[
            if (index > 0) const Divider(height: 1, color: AppColors.divider),
            stocks[index].price <= 0
                ? ListTile(
                    title: AppText(stocks[index].symbol),
                    subtitle: AppText(
                      stocks[index].name.isEmpty
                          ? stocks[index].exchange
                          : stocks[index].name,
                    ),
                    trailing: const AppText(
                      'Unavailable',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    onTap: () => onOpen(stocks[index]),
                  )
                : StockListTile(
                    stock: stocks[index],
                    onTap: () => onOpen(stocks[index]),
                  ),
          ],
        ],
      ),
    );
  }
}

class _NewsSection extends StatelessWidget {
  const _NewsSection({
    required this.news,
    required this.onOpen,
    required this.onRetry,
  });

  final List<MarketNewsItem> news;
  final ValueChanged<MarketNewsItem> onOpen;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (news.isEmpty) {
      return AppCard(
        radius: AppRadius.sm,
        child: Row(
          children: [
            const Icon(Icons.newspaper_outlined, color: AppColors.textTertiary),
            const SizedBox(width: AppSpacing.md),
            const Expanded(
              child: AppText(
                'Live market news is temporarily unavailable.',
                style: AppTypography.bodySmall,
              ),
            ),
            IconButton(
              onPressed: onRetry,
              tooltip: tr('Retry news'),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final oneColumn = constraints.maxWidth < 340;
        final width = oneColumn
            ? constraints.maxWidth
            : (constraints.maxWidth - AppSpacing.sm - 2) / 2;
        return Wrap(
          spacing: AppSpacing.sm + 2,
          runSpacing: AppSpacing.sm + 2,
          children: news
              .take(2)
              .map(
                (item) => SizedBox(
                  width: width,
                  child: AppCard(
                    radius: AppRadius.sm,
                    padding: EdgeInsets.zero,
                    onTap: () => onOpen(item),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.sm + 3),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppText(
                            item.title,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.labelMedium.copyWith(
                              fontWeight: FontWeight.w800,
                              height: 1.28,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          AppText(
                            '${item.source}  ·  ${homeRelativeTime(item.publishedAt)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption.copyWith(fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _TradeEntry extends StatelessWidget {
  const _TradeEntry({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: AppRadius.sm,
      backgroundColor: AppColors.brandPrimarySoft,
      bordered: false,
      onTap: onTap,
      child: Row(
        children: [
          const Icon(
            Icons.swap_horiz_rounded,
            color: AppColors.brandPrimary,
            size: AppMotion.iconToolbar,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  'Open Trade',
                  style: AppTypography.labelLarge.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                AppText(
                  'Place orders from the Trade tab',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textTertiary,
          ),
        ],
      ),
    );
  }
}

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget bar({double height = 16, double width = double.infinity}) =>
        Container(
          height: height,
          width: width,
          decoration: BoxDecoration(
            color: AppColors.surfaceSecondary,
            borderRadius: AppRadius.borderSm,
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        bar(height: 132),
        const SizedBox(height: AppSpacing.sm),
        bar(height: 72),
        const SizedBox(height: AppSpacing.md),
        bar(height: 88),
        const SizedBox(height: AppSpacing.md),
        bar(height: 120),
      ],
    );
  }
}
