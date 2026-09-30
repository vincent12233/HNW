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

part 'home_dashboard_movers.dart';
part 'home_dashboard_content.dart';
part 'home_dashboard_overview.dart';

class HomeDashboard extends StatefulWidget {
  const HomeDashboard({
    super.key,
    required this.accountName,
    required this.totalAssets,
    required this.availableFunds,
    required this.frozenFunds,
    required this.realizedPnl,
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
    this.historyUpdatedAt,
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
  final double realizedPnl;
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
  final DateTime? historyUpdatedAt;
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
          const SizedBox(height: AppSpacing.sm + 2),
          MarketStatusCard(
            isOpen: widget.marketOpen,
            hours: widget.marketHours,
            quotesConnected: widget.quotesConnected,
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
                    'Realized P&L',
                    _money(widget.realizedPnl, signed: true),
                    color: widget.hideBalances || !widget.accountLoaded
                        ? AppColors.textPrimary
                        : AppUiGainLoss.color(widget.realizedPnl),
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
