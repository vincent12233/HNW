part of 'home_dashboard.dart';

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
                  height: 58,
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
          if (dashboard.historyError != null) ...[
            AppText(
              dashboard.historyError!,
              style: AppTypography.caption.copyWith(color: inverseMuted),
            ),
            if (dashboard.historyUpdatedAt case final updatedAt?)
              AppText(
                'Last updated ${formatIstDateTime(updatedAt)}',
                style: AppTypography.caption.copyWith(color: inverseMuted),
              ),
          ],
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
        showChevron: false,
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
        Expanded(
          child: AppText(
            title,
            style: AppTypography.sectionTitle.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 0.1,
            ),
          ),
        ),
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
                  size: 16,
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
        final columns = constraints.maxWidth >= 360 && scale <= 1.2
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
          radius: AppRadius.md,
          padding: EdgeInsets.fromLTRB(
            MediaQuery.sizeOf(context).width >= 360
                ? AppSpacing.sm
                : AppSpacing.md,
            AppSpacing.sm + 2,
            MediaQuery.sizeOf(context).width >= 360
                ? AppSpacing.sm
                : AppSpacing.md,
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
                ],
              ),
              if (item.available && item.history.length >= 2) ...[
                const SizedBox(height: AppSpacing.xs),
                ExcludeSemantics(
                  child: SizedBox(
                    key: ValueKey<String>('home-index-chart-${item.label}'),
                    width: double.infinity,
                    height: 22,
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
        ),
      ),
    );
  }
}
