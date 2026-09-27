part of 'markets_page.dart';

extension _MarketsIndicesSection on _MarketsPageState {
  Widget _indicesContent() {
    final horizontalPadding = MediaQuery.sizeOf(context).width < 360
        ? 14.0
        : 16.0;
    final vix = _indexQuote(const ['INDIAVIX', 'INDIA VIX', 'VIX']);
    final dow = _indexQuote(const ['DJI', 'DOWJONES', 'DOW JONES']);
    final nasdaq = _indexQuote(const ['IXIC', 'NASDAQ']);
    final sp500 = _indexQuote(const ['GSPC', 'SP500', 'S&P500', 'S&P 500']);
    final ftse = _indexQuote(const ['FTSE', 'FTSE100', 'FTSE 100']);
    final indices = [
      ('NIFTY 50', widget.nifty50Price, widget.nifty50Change),
      ('SENSEX', widget.sensexPrice, widget.sensexChange),
      ('BANK NIFTY', widget.bankNiftyPrice, widget.bankNiftyChange),
      ('INDIA VIX', vix?.$1 ?? 0, vix?.$2 ?? 0),
    ];
    final globalIndices = [
      ('DOW JONES', dow?.$1 ?? 0, dow?.$2 ?? 0),
      ('NASDAQ', nasdaq?.$1 ?? 0, nasdaq?.$2 ?? 0),
      ('S&P 500', sp500?.$1 ?? 0, sp500?.$2 ?? 0),
      ('FTSE 100', ftse?.$1 ?? 0, ftse?.$2 ?? 0),
    ];
    final gainers = widget.stocks.where((stock) => stock.change > 0).toList()
      ..sort((a, b) => b.change.compareTo(a.change));
    final losers = widget.stocks.where((stock) => stock.change < 0).toList()
      ..sort((a, b) => a.change.compareTo(b.change));
    final unchanged = widget.stocks.where((stock) => stock.change == 0).length;
    final mostActive = [...widget.stocks]
      ..sort((a, b) => b.volume.compareTo(a.volume));
    final yearHigh =
        widget.stocks
            .where((stock) => _yearRanges.containsKey(_instrumentKey(stock)))
            .toList()
          ..sort((left, right) {
            final leftHigh = _yearRanges[_instrumentKey(left)]!.$2;
            final rightHigh = _yearRanges[_instrumentKey(right)]!.$2;
            return ((leftHigh - left.price).abs() / leftHigh).compareTo(
              (rightHigh - right.price).abs() / rightHigh,
            );
          });
    final yearLow =
        widget.stocks
            .where((stock) => _yearRanges.containsKey(_instrumentKey(stock)))
            .toList()
          ..sort((left, right) {
            final leftLow = _yearRanges[_instrumentKey(left)]!.$1;
            final rightLow = _yearRanges[_instrumentKey(right)]!.$1;
            return ((left.price - leftLow).abs() / leftLow).compareTo(
              (right.price - rightLow).abs() / rightLow,
            );
          });
    final moverRows = switch (selectedMoverFilter) {
      0 => mostActive,
      1 => gainers,
      2 => losers,
      3 => yearHigh,
      4 => yearLow,
      _ => <StockQuote>[],
    };

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(horizontalPadding, 8, horizontalPadding, 24),
      children: [
        _marketSectionHeading(
          'Indian Indices',
          onViewAll: () => _showIndices('Indian Indices', indices),
        ),
        const SizedBox(height: 12),
        _indexGrid(indices),
        const SizedBox(height: 18),
        _marketSectionHeading(
          'Global Indices',
          onViewAll: () => _showIndices('Global Indices', globalIndices),
        ),
        const SizedBox(height: 12),
        _indexGrid(globalIndices),
        if (_marketsFeatured.isNotEmpty) ...[
          const SizedBox(height: 18),
          _marketSectionHeading('Featured'),
          const SizedBox(height: 12),
          _moverTable(_marketsFeatured.take(5).toList()),
        ],
        const SizedBox(height: 18),
        _marketSectionHeading(
          'Market Movers',
          onViewAll: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => MoversListPage(
                gainers: gainers,
                losers: losers,
                mostActive: mostActive,
                yearHigh: yearHigh,
                yearLow: yearLow,
                initialFilter: selectedMoverFilter,
                yearRangesLoading: _yearRangesLoading,
                onNeedYearRanges: () => unawaited(_loadYearRanges()),
                onStockTap: widget.onStockTap,
                marketOpen: widget.marketOpen,
                marketHours: widget.marketHours,
                quotesConnected: widget.quotesConnected,
                onRefresh: _refreshAll,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        _moverFilters(),
        const SizedBox(height: 8),
        _moverTable(moverRows.take(5).toList()),
        const SizedBox(height: 22),
        _marketSectionHeading('Market Breadth', showViewAll: false),
        const SizedBox(height: 12),
        _marketBreadth(gainers.length, losers.length, unchanged),
        const SizedBox(height: 18),
        _marketBanner(),
      ],
    );
  }

  (double, double)? _indexQuote(List<String> symbols) {
    for (final symbol in symbols) {
      final quote = widget.indexQuotes[symbol];
      if (quote != null) return quote;
    }
    return null;
  }

  Widget _marketSectionHeading(
    String title, {
    bool showViewAll = true,
    VoidCallback? onViewAll,
  }) => Row(
    children: [
      Expanded(
        child: AppText(
          title,
          style: AppTypography.titleMedium.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      if (showViewAll && onViewAll != null)
        TextButton.icon(
          onPressed: onViewAll,
          style: TextButton.styleFrom(
            minimumSize: const Size(44, 44),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          ),
          label: AppText(
            'View All',
            style: AppTypography.labelMedium.copyWith(
              color: AppColors.brandPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          iconAlignment: IconAlignment.end,
          icon: const Icon(Icons.chevron_right_rounded, size: 17),
        ),
    ],
  );

  Widget _indexGrid(List<(String, double, double)> values) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(1);
      final gap = constraints.maxWidth < 360 ? 8.0 : 6.0;
      final columns = constraints.maxWidth >= 360 && scale <= 1.15 ? 4 : 2;
      final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: values
            .map((item) => SizedBox(width: width, child: _indexCard(item)))
            .toList(),
      );
    },
  );

  void _showIndices(String title, List<(String, double, double)> items) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => IndexListPage(
          title: title,
          items: items.map(_toIndexQuote).toList(),
          marketOpen: widget.marketOpen,
          marketHours: widget.marketHours,
          quotesConnected: widget.quotesConnected,
          onRefresh: _refreshAll,
        ),
      ),
    );
  }

  MarketIndexQuote _toIndexQuote((String, double, double) item) {
    final ref =
        MarketIndexRef.byLabel(item.$1) ??
        MarketIndexRef(
          label: item.$1,
          symbol: item.$1.replaceAll(' ', ''),
          exchange: 'NSE',
          venue: 'NSE',
        );
    return MarketIndexQuote(
      ref: ref,
      price: item.$2,
      changePercent: item.$3,
      history: _indexHistory[item.$1] ?? const <double>[],
    );
  }

  void _openIndexDetail((String, double, double) item) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => IndexDetailPage(
          quote: _toIndexQuote(item),
          marketOpen: widget.marketOpen,
          marketHours: widget.marketHours,
          quotesConnected: widget.quotesConnected,
        ),
      ),
    );
  }

  Widget _indexCard((String, double, double) item) {
    final venue = item.$1.toUpperCase().contains('SENSEX')
        ? 'BSE'
        : const {
            'DOW JONES',
            'NASDAQ',
            'S&P 500',
            'FTSE 100',
          }.contains(item.$1.toUpperCase())
        ? 'GLOBAL'
        : 'NSE';
    return MarketsIndexCard(
      label: item.$1,
      price: item.$2,
      changePercent: item.$3,
      venue: venue,
      history: _indexHistory[item.$1] ?? const <double>[],
      onTap: () => _openIndexDetail(item),
    );
  }

  Widget _moverFilters() => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children:
          [
                'Most Active',
                'Top Gainers',
                'Top Losers',
                '52 Week High',
                '52 Week Low',
              ]
              .asMap()
              .entries
              .map(
                (entry) => InkWell(
                  borderRadius: AppRadius.borderSm,
                  onTap: () {
                    _updateState(() => selectedMoverFilter = entry.key);
                    if (entry.key >= 3) unawaited(_loadYearRanges());
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: AppSpacing.sm),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md + 1,
                      vertical: AppSpacing.sm + 1,
                    ),
                    constraints: const BoxConstraints(
                      minHeight: AppMotion.tapTarget,
                    ),
                    decoration: BoxDecoration(
                      color: entry.key == selectedMoverFilter
                          ? AppColors.brandPrimarySoft
                          : AppColors.surface,
                      borderRadius: AppRadius.borderSm,
                      border: Border.all(
                        color: entry.key == selectedMoverFilter
                            ? AppColors.brandPrimary.withValues(alpha: 0.28)
                            : AppColors.border,
                      ),
                    ),
                    child: AppText(
                      entry.value,
                      style: AppTypography.labelSmall.copyWith(
                        color: entry.key == selectedMoverFilter
                            ? AppColors.brandPrimary
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
    ),
  );

  Widget _moverTable(List<StockQuote> rows) {
    if (rows.isEmpty) {
      return AppCard(
        padding: const EdgeInsets.all(AppSpacing.lg + 2),
        child: Row(
          children: [
            if (_yearRangesLoading && selectedMoverFilter >= 3)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  semanticsLabel: 'Loading yearly market range',
                ),
              )
            else
              const Icon(
                Icons.query_stats_rounded,
                color: AppColors.textSecondary,
              ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: AppText(
                _yearRangesLoading && selectedMoverFilter >= 3
                    ? 'Loading one-year market history...'
                    : selectedMoverFilter >= 3
                    ? 'One-year history is unavailable for these instruments.'
                    : 'No instruments match this market filter.',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return AppCard(
      radius: AppRadius.sm,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final stock in rows)
            StockListTile(
              key: ValueKey('mover-${stock.exchange}:${stock.symbol}'),
              stock: stock,
              onTap: () => widget.onStockTap(stock),
            ),
        ],
      ),
    );
  }

  Widget _marketBreadth(int advances, int declines, int unchanged) {
    final total = advances + declines + unchanged;
    if (total == 0) {
      return AppCard(
        radius: AppRadius.sm,
        child: AppText(
          'Market breadth unavailable',
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      );
    }
    return AppCard(
      radius: AppRadius.sm,
      padding: const EdgeInsets.all(AppSpacing.md + 2),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: AppText(
              'Loaded instruments',
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm - 1),
          LayoutBuilder(
            builder: (context, constraints) {
              final metrics = [
                _breadthMetric('Advances', advances, AppColors.gain),
                _breadthMetric('Declines', declines, AppColors.loss),
                _breadthMetric('Unchanged', unchanged, AppColors.neutral),
              ];
              if (constraints.maxWidth < 280 ||
                  MediaQuery.textScalerOf(context).scale(1) > 1.3) {
                return Wrap(
                  spacing: AppSpacing.xl,
                  runSpacing: AppSpacing.md,
                  children: metrics,
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final metric in metrics) Expanded(child: metric),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.md - 2),
          ClipRRect(
            borderRadius: AppRadius.borderPill,
            child: Row(
              children: [
                if (advances > 0)
                  Expanded(
                    flex: advances,
                    child: Container(height: 8, color: AppColors.gain),
                  ),
                if (declines > 0)
                  Expanded(
                    flex: declines,
                    child: Container(height: 8, color: AppColors.loss),
                  ),
                if (unchanged > 0)
                  Expanded(
                    flex: unchanged,
                    child: Container(height: 8, color: AppColors.neutral),
                  ),
              ],
            ),
          ),
          AppText(
            '${(advances / total * 100).toStringAsFixed(0)}% advancing',
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _breadthMetric(String label, int count, Color color) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      AppText(
        label,
        style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
      ),
      const SizedBox(height: AppSpacing.xxs),
      AppText(
        count.toString(),
        style: AppTypography.numericSmall.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    ],
  );
}
