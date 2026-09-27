part of 'product_portfolio_page.dart';

extension _ProductPortfolioSummarySection on _ProductPortfolioPageState {
  List<Widget> _content(Map<String, dynamic> data) {
    final categories = _rows(data['categories']);
    final history = data['history'] is Map
        ? Map<String, dynamic>.from(data['history'])
        : <String, dynamic>{};
    final points = _rows(history['points']);
    final empty = _availableNumber(data['positionCount']) == 0;
    final hasHistory =
        points.length >= 2 &&
        points.every(
          (point) => _availableNumber(point['productValue']) != null,
        );
    final inverseMuted = AppColors.textInverse.withValues(alpha: 0.7);
    return [
      const SizedBox(height: AppSpacing.md),
      // PRIMARY: hero Total Portfolio Value + Total Returns + period/sparkline
      Container(
        padding: const EdgeInsets.all(AppSpacing.md + 2),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.brandPrimary, AppColors.brandGradientEnd],
          ),
          borderRadius: AppRadius.borderMd,
          border: Border.all(color: Colors.white24),
          boxShadow: AppShadows.brandHero,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: AppText(
                    _portfolioCopy(
                      'portfolio.value_label',
                      'Total Portfolio Value',
                    ),
                    style: AppTypography.labelLarge.copyWith(
                      color: inverseMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: tr(_hidden ? 'Show balances' : 'Hide balances'),
                  onPressed: () => _updateState(() => _hidden = !_hidden),
                  icon: Icon(
                    _hidden
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: inverseMuted,
                    size: 20,
                  ),
                ),
              ],
            ),
            AppText(
              _money(data['currentValue']),
              style: AppTypography.numericInverse.copyWith(fontSize: 28),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppText(
              key: const ValueKey('portfolio-hero-returns'),
              '${tr('Total Returns')}: ${_pnlText(data['totalPnl'])}',
              style: AppTypography.bodyMedium.copyWith(
                color: _hidden || _number(data['totalPnl']) == 0
                    ? inverseMuted
                    : _number(data['totalPnl']) > 0
                    ? AppColors.chartGain
                    : const Color(0xFFFFB4B4),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (!empty && !_hidden)
              SizedBox(
                height: 68,
                width: double.infinity,
                child: AppStatusSwitch(
                  switchKey: '$_period|$hasHistory|$_loading',
                  child: _loading
                      ? Center(
                          child: CircularProgressIndicator(
                            color: AppColors.textInverse,
                            strokeWidth: 2,
                            semanticsLabel: tr('Loading performance'),
                          ),
                        )
                      : !hasHistory
                      ? Center(
                          child: AppText(
                            _portfolioCopy(
                              'portfolio.insufficient_history',
                              'Insufficient history',
                            ),
                            style: AppTypography.bodyMedium.copyWith(
                              color: inverseMuted,
                            ),
                          ),
                        )
                      : CustomPaint(
                          key: const ValueKey('portfolio-history-chart'),
                          painter: _ValueHistoryPainter(
                            points
                                .map((row) => _number(row['productValue']))
                                .toList(),
                          ),
                        ),
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final period in ['1D', '1W', '1M', '3M', '1Y', 'All'])
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.xs),
                      child: ChoiceChip(
                        key: ValueKey('portfolio-period-$period'),
                        label: AppText(period),
                        selected: _period == period,
                        onSelected: (_) {
                          if (period != _period) _load(period);
                        },
                        showCheckmark: false,
                        selectedColor: AppColors.textInverse,
                        backgroundColor: Colors.white10,
                        side: BorderSide(
                          color: _period == period
                              ? Colors.transparent
                              : Colors.white12,
                        ),
                        visualDensity: VisualDensity.compact,
                        labelStyle: AppTypography.labelSmall.copyWith(
                          fontSize: 10,
                          color: _period == period
                              ? AppColors.brandDark
                              : inverseMuted,
                        ),
                        labelPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.lg + 2),
      // SECONDARY: Investment Summary metrics in AppCard
      _datedHeading(
        AppContentService.instance.current.text(
          'trading',
          'portfolio.summary_heading',
          fallback: 'Investment Summary',
        ),
        '${tr('As of')} ${_date(data['asOf'])}',
      ),
      const SizedBox(height: AppSpacing.md),
      AppCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md + 2,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _metrics([
              ('Invested', data['invested']),
              ('Current Value', data['currentValue']),
              ('Total Returns', data['totalPnl']),
            ]),
          ],
        ),
      ),
      if (empty) ...[
        const SizedBox(height: AppSpacing.sectionGap),
        SizedBox(
          height: 280,
          child: AppEmptyState(
            icon: Icons.account_balance_outlined,
            title: AppContentService.instance.current.text(
              'trading',
              'portfolio.empty_title',
              fallback: 'No investments yet',
            ),
            message: AppContentService.instance.current.text(
              'trading',
              'portfolio.empty_subtitle',
              fallback: 'No Institutional, OTC or IPO holdings yet.',
            ),
          ),
        ),
        Center(
          child: FilledButton.icon(
            onPressed: widget.onExplore,
            icon: const Icon(Icons.arrow_forward),
            label: AppText(
              AppContentService.instance.current.text(
                'trading',
                'portfolio.explore_cta',
                fallback: 'Explore offers',
              ),
            ),
          ),
        ),
      ] else ...[
        const SizedBox(height: AppSpacing.sectionGap),
        // DETAIL: Asset Allocation
        _heading(
          AppContentService.instance.current.text(
            'trading',
            'portfolio.allocation_heading',
            fallback: 'Asset Allocation',
          ),
          action: () => _showHoldings(categories),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final legend = Column(
                children: categories
                    .map(
                      (category) => Semantics(
                        button: true,
                        label:
                            '${tr(category['category'].toString())}, '
                            '${tr('Current Value')} ${_money(category['currentValue'])}, '
                            '${tr('Allocation')} ${_percent(category['allocationPercent'])}',
                        child: ExcludeSemantics(
                          child: InkWell(
                            onTap: () => _showHoldings([category]),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.sm + 2,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.circle,
                                    size: 10,
                                    color:
                                        _ProductPortfolioPageState._categoryColor(
                                          category['category'],
                                        ),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        AppText(
                                          tr(category['category'].toString()),
                                          style: AppTypography.labelSmall,
                                        ),
                                        const SizedBox(height: AppSpacing.xs),
                                        AppText(
                                          _money(category['currentValue']),
                                          style: AppTypography.numericSmall
                                              .copyWith(fontSize: 10),
                                        ),
                                        const SizedBox(height: AppSpacing.xs),
                                        if (!_hidden &&
                                            _availableNumber(
                                                  category['allocationPercent'],
                                                ) !=
                                                null)
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              3,
                                            ),
                                            child: LinearProgressIndicator(
                                              value:
                                                  (_number(
                                                            category['allocationPercent'],
                                                          ) /
                                                          100)
                                                      .clamp(0.0, 1.0),
                                              minHeight: 3,
                                              color:
                                                  _ProductPortfolioPageState._categoryColor(
                                                    category['category'],
                                                  ),
                                              backgroundColor:
                                                  AppColors.surfaceSecondary,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  AppText(
                                    _percent(category['allocationPercent']),
                                    style: AppTypography.numericSmall.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.xs),
                                  const Icon(Icons.chevron_right, size: 18),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              );
              final donut = Semantics(
                image: true,
                label:
                    '${_portfolioCopy('portfolio.allocation_heading', 'Asset Allocation')}, '
                    '${tr('Current Value')} ${_money(data['currentValue'])}, 100%',
                child: ExcludeSemantics(
                  child: SizedBox.square(
                    dimension: 128,
                    child: CustomPaint(
                      painter: _AllocationPainter(
                        categories
                            .map((c) => _number(c['currentValue']))
                            .toList(),
                        categories
                            .map(
                              (c) => _ProductPortfolioPageState._categoryColor(
                                c['category'],
                              ),
                            )
                            .toList(),
                      ),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.lg + 2),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: AppText(
                                  _money(data['currentValue']),
                                  style: AppTypography.numericSmall.copyWith(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              AppText(
                                '100%',
                                style: AppTypography.caption.copyWith(
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
              if (_hidden ||
                  _number(data['currentValue']) <= 0 ||
                  categories.any(
                    (category) =>
                        _availableNumber(category['currentValue']) == null,
                  )) {
                return legend;
              }
              if (constraints.maxWidth < 320 ||
                  MediaQuery.textScalerOf(context).scale(1) > 1.2) {
                return Column(
                  children: [
                    donut,
                    const SizedBox(height: AppSpacing.md - 2),
                    legend,
                  ],
                );
              }
              return Row(
                children: [
                  donut,
                  const SizedBox(width: AppSpacing.md + 2),
                  Expanded(child: legend),
                ],
              );
            },
          ),
        ),
        // DETAIL: Asset Details
        _heading(
          _portfolioCopy('portfolio.asset_details_heading', 'Asset Details'),
        ),
        const SizedBox(height: AppSpacing.sm),
        ...categories.map(
          (category) => AppCard(
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            borderColor: AppColors.divider,
            shadow: AppCardShadow.small,
            onTap: () => _showHoldings([category]),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: _ProductPortfolioPageState._categoryColor(
                          category['category'],
                        ),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Icon(
                        category['category'] == 'OTC'
                            ? Icons.verified_user_outlined
                            : category['category'] == 'IPO'
                            ? Icons.rocket_launch_outlined
                            : Icons.account_balance_outlined,
                        color: AppColors.textInverse,
                        size: 17,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md - 2),
                    Expanded(
                      child: AppText(
                        tr(category['category'].toString()),
                        style: AppTypography.titleSmall,
                      ),
                    ),
                    const Icon(Icons.chevron_right, size: 20),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm - 2),
                _metrics([
                  ('Current Value', category['currentValue']),
                  ('Allocation', category['allocationPercent']),
                  ('Invested', category['invested']),
                  ('Total Returns', category['totalPnl']),
                ]),
                if (!_hidden &&
                    _availableNumber(category['allocationPercent']) !=
                        null) ...[
                  const SizedBox(height: AppSpacing.md - 2),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: (_number(category['allocationPercent']) / 100)
                          .clamp(0.0, 1.0),
                      minHeight: 4,
                      color: _ProductPortfolioPageState._categoryColor(
                        category['category'],
                      ),
                      backgroundColor: AppColors.surfaceSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _heading(
          _portfolioCopy(
            'portfolio.holdings_heading',
            'Holdings and Positions',
          ),
        ),
        AppText(
          _portfolioCopy(
            'portfolio.holdings_caption',
            'Product holdings from the current portfolio response. Equity positions remain under Trade.',
          ),
          style: AppTypography.caption,
        ),
        const SizedBox(height: AppSpacing.sm),
        ..._productHoldings(categories, data['asOf']),
        const SizedBox(height: AppSpacing.md),
        // DETAIL: Performance
        _heading(
          _portfolioCopy('portfolio.performance_heading', 'Performance'),
          action: () => _showPerformance(data, history),
        ),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md + 2,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _metrics([
                ('Unrealized P&L', data['unrealizedPnl']),
                ('Realized P&L', data['realizedPnl']),
                (
                  'Recorded P&L',
                  _loading ? null : history['productProfitChange'],
                ),
              ]),
              const SizedBox(height: AppSpacing.md),
              AppText(
                '${tr('Best Segment')}: ${_hidden ? '******' : tr(data['bestSegment']?.toString() ?? '--')}',
                style: AppTypography.labelLarge,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        // DETAIL: Recent Activity
        _heading(
          _portfolioCopy('portfolio.recent_activity', 'Recent Activity'),
          action: () => _showActivity(_rows(data['activity'])),
        ),
        if (_rows(data['activity']).isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
            child: Center(
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.brandPrimarySoft,
                      borderRadius: AppRadius.borderSm,
                    ),
                    child: const Icon(
                      Icons.history_rounded,
                      color: AppColors.brandPrimary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppText(
                    _portfolioCopy(
                      'portfolio.no_activity',
                      'No product activity yet',
                    ),
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ..._rows(data['activity']).take(5).map(_activityTile),
      ],
      const SizedBox(height: AppSpacing.xxl),
    ];
  }
}
