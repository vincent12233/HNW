part of 'product_portfolio_page.dart';

extension _ProductPortfolioDetailsSection on _ProductPortfolioPageState {
  Widget _heading(String title, {VoidCallback? action}) => LayoutBuilder(
    builder: (context, constraints) {
      final heading = AppText(
        title,
        style: AppTypography.sectionTitle.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.1,
        ),
      );
      final button = action == null
          ? null
          : TextButton(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                minimumSize: const Size(
                  AppMotion.tapTarget,
                  AppMotion.tapTarget,
                ),
              ),
              onPressed: action,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppText(
                    _portfolioCopy('portfolio.view_details', 'View Details'),
                  ),
                  const SizedBox(width: AppSpacing.xxs),
                  const Icon(Icons.chevron_right_rounded, size: 17),
                ],
              ),
            );
      if (constraints.maxWidth < 320 ||
          MediaQuery.textScalerOf(context).scale(1) > 1.3) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [heading, ?button],
        );
      }
      return Row(
        children: [
          Expanded(child: heading),
          ?button,
        ],
      );
    },
  );

  Widget _datedHeading(String title, String date) => LayoutBuilder(
    builder: (context, constraints) {
      final heading = AppText(
        title,
        style: AppTypography.sectionTitle.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      );
      final timestamp = AppText(
        date,
        style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
      );
      if (constraints.maxWidth < 320 ||
          MediaQuery.textScalerOf(context).scale(1) > 1.3) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            heading,
            const SizedBox(height: AppSpacing.xs),
            timestamp,
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: heading),
          const SizedBox(width: AppSpacing.md),
          Flexible(child: timestamp),
        ],
      );
    },
  );

  Widget _metrics(List<(String, dynamic)> items) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(1);
      final columns = (constraints.maxWidth / (110 * scale)).floor().clamp(
        1,
        items.length,
      );
      return Wrap(
        runSpacing: AppSpacing.md + 2,
        children: items
            .map(
              (item) => SizedBox(
                width: constraints.maxWidth / columns,
                child: Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.md - 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(
                        item.$1,
                        style: AppTypography.caption.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs + 1),
                      AppText(
                        item.$1 == 'Allocation'
                            ? _percent(item.$2)
                            : item.$1.contains('P&L') ||
                                  item.$1.contains('Returns')
                            ? _pnlText(item.$2)
                            : _money(item.$2),
                        style: AppTypography.numericSmall.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color:
                              item.$1.contains('P&L') ||
                                  item.$1.contains('Returns')
                              ? _pnlColor(item.$2)
                              : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
            .toList(),
      );
    },
  );

  void _showHoldings(List<Map<String, dynamic>> categories) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: AppText(
              categories.length == 1
                  ? categories.first['category'].toString()
                  : _portfolioCopy(
                      'portfolio.asset_details_heading',
                      'Asset Details',
                    ),
            ),
          ),
          body: ListView(
            padding: AppSpacing.page,
            children: [
              for (final category in categories) ...[
                AppText(
                  tr(category['category'].toString()),
                  style: AppTypography.titleLarge,
                ),
                if (_rows(category['positions']).isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xxl,
                    ),
                    child: Center(
                      child: AppText(
                        _portfolioCopy(
                          'portfolio.no_holdings',
                          'No product holdings in the current response.',
                        ),
                        style: AppTypography.bodyMedium,
                      ),
                    ),
                  ),
                for (final position in _rows(category['positions']))
                  AppCard(
                    margin: const EdgeInsets.only(top: AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppText(
                          '${position['symbol']} · ${position['exchange']}',
                          style: AppTypography.titleSmall.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        AppText(
                          position['name'].toString(),
                          style: AppTypography.bodyMedium,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AppText(
                          '${tr('Quantity')}: ${_quantity(position['quantity'])} · ${tr('Available')}: ${_quantity(position['availableQuantity'])} · Frozen ${_frozenText(position)}',
                          style: AppTypography.bodySmall,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _metrics([
                          ('Average price', position['averagePrice']),
                          ('Current Value', position['currentValue']),
                          ('Unrealized P&L', position['unrealizedPnl']),
                        ]),
                        if (position['valuationSource'] == 'COST')
                          Padding(
                            padding: const EdgeInsets.only(
                              top: AppSpacing.md - 2,
                            ),
                            child: AppText(
                              _portfolioCopy(
                                'portfolio.detail.valuation_cost',
                                'Valued at cost. Market quote unavailable.',
                              ),
                              style: AppTypography.caption,
                            ),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: AppSpacing.xl),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _activityTile(Map<String, dynamic> activity) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(
      activity['type'] == 'IPO' ? Icons.trending_up : Icons.swap_horiz,
      color: _ProductPortfolioPageState._categoryColor(activity['category']),
    ),
    title: AppText(
      '${activity['symbol']} · ${tr(activity['category']?.toString() ?? '')}',
      style: AppTypography.labelLarge,
    ),
    subtitle: AppText(
      '${tr(activity['status'].toString())} · ${_date(activity['at'])}',
      style: AppTypography.caption,
    ),
    trailing: const Icon(Icons.chevron_right, size: 18),
    onTap: () => showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: AppText(activity['symbol'].toString()),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText('${tr('Status')}: ${tr(activity['status'].toString())}'),
              const SizedBox(height: AppSpacing.sm),
              AppText('${tr('Quantity')}: ${_quantity(activity['quantity'])}'),
              AppText(
                '${tr('Filled / allocated')}: ${_quantity(activity['filledQuantity'])}',
              ),
              AppText('${tr('Amount')}: ${_money(activity['amount'])}'),
              const SizedBox(height: AppSpacing.sm),
              AppText(_date(activity['at'])),
              const SizedBox(height: AppSpacing.sm),
              SelectableText(activity['reference'].toString()),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: AppText(_portfolioCopy('portfolio.close', 'Close')),
          ),
        ],
      ),
    ),
  );

  void _showActivity(List<Map<String, dynamic>> rows) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => Scaffold(
            appBar: AppBar(
              title: AppText(
                _portfolioCopy('portfolio.recent_activity', 'Recent Activity'),
              ),
            ),
            body: ListView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              children: rows.isEmpty
                  ? [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.xxl,
                        ),
                        child: Center(
                          child: AppText(
                            _portfolioCopy(
                              'portfolio.no_activity',
                              'No product activity yet',
                            ),
                            style: AppTypography.bodyMedium,
                          ),
                        ),
                      ),
                    ]
                  : rows.map(_activityTile).toList(),
            ),
          ),
        ),
      );

  void _showPerformance(
    Map<String, dynamic> data,
    Map<String, dynamic> history,
  ) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText(
              _portfolioCopy('portfolio.performance_heading', 'Performance'),
              style: AppTypography.headline,
            ),
            const SizedBox(height: AppSpacing.lg),
            _metrics([
              ('Unrealized P&L', data['unrealizedPnl']),
              ('Realized P&L', data['realizedPnl']),
              ('Recorded P&L', history['productProfitChange']),
            ]),
            const SizedBox(height: AppSpacing.xl),
            AppText('${tr('Period')}: $_period'),
            AppText('${tr('Since')}: ${_date(history['productFrom'])}'),
            AppText('${tr('As of')}: ${_date(history['to'])}'),
            AppText(
              _portfolioCopy(
                'portfolio.performance_source_note',
                'Source: recorded product snapshots. Returns cover recorded observations only. Deposits and ordinary stocks are excluded.',
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
