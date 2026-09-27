part of 'markets_page.dart';

extension _MarketsContentSection on _MarketsPageState {
  Widget _selectedContent({int? contentIndex}) {
    switch (contentIndex ?? selectedTab) {
      case 0:
        return RefreshIndicator(
          onRefresh: _refreshAll,
          child: _watchlistContent(),
        );

      case 1:
        return RefreshIndicator(
          onRefresh: _refreshAll,
          child: _indicesContent(),
        );

      case 2:
        return RefreshIndicator(
          onRefresh: _refreshAll,
          child: _stockList(
            _filteredStocks,
            emptyTitle: 'No instruments available',
            emptySubtitle:
                'Stock quotes will appear when enabled by the market catalog.',
          ),
        );

      case 3:
        final hasCategories = widget.stocks.any(
          (stock) => stock.category?.trim().isNotEmpty == true,
        );
        return RefreshIndicator(
          onRefresh: _refreshAll,
          child: hasCategories
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: AppSpacing.page,
                  children: [
                    SectorPerformance(stocks: widget.stocks),
                    const SizedBox(height: AppSpacing.lg + 2),
                    _sectorBreakdown(),
                  ],
                )
              : _emptyState(
                  Icons.category_outlined,
                  'No sector data',
                  'Sector classifications are currently unavailable for this market catalog.',
                ),
        );

      case 4:
        return RefreshIndicator(
          onRefresh: _refreshAll,
          child: _categoryList(
            _MarketsPageState._foKeywords,
            emptyTitle: 'F&O instruments unavailable',
            emptySubtitle:
                'Derivative contracts will appear when enabled by the market catalog.',
            browseOnlyLabel: 'F&O',
          ),
        );
      case 5:
        return RefreshIndicator(onRefresh: _refreshAll, child: _etfList());
      case 6:
        return RefreshIndicator(
          onRefresh: _refreshAll,
          child: _categoryList(
            _MarketsPageState._commodityKeywords,
            emptyTitle: 'Commodity instruments unavailable',
            emptySubtitle:
                'Commodity quotes will appear when enabled by the market catalog.',
            browseOnlyLabel: 'Commodities',
          ),
        );
      case 7:
        return RefreshIndicator(
          onRefresh: _refreshAll,
          child: _categoryList(
            _MarketsPageState._currencyKeywords,
            emptyTitle: 'Currency instruments unavailable',
            emptySubtitle:
                'Currency quotes will appear when enabled by the market catalog.',
            browseOnlyLabel: 'Currency',
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _watchlistContent() {
    if (_watchlistLoading && _watchlistStocks.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: constraints.maxHeight,
              child: const AppLoadingView(message: 'Loading watchlist…'),
            ),
          );
        },
      );
    }
    if (_watchlistFailed && _watchlistStocks.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: constraints.maxHeight,
              child: AppErrorView(
                title: _marketCopy(
                  'markets.watchlist_error_title',
                  'Unable to load watchlist',
                ),
                message: _marketCopy(
                  'markets.watchlist_error_body',
                  'Watchlist data is unavailable. Please try again.',
                ),
                onRetry: () => unawaited(_loadWatchlist()),
              ),
            ),
          );
        },
      );
    }
    if (_watchlistStocks.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.xxl),
        children: [
          const SizedBox(height: AppSpacing.xxxl + AppSpacing.lg),
          Icon(
            Icons.star_border_rounded,
            size: 40,
            color: AppColors.textSecondary.withValues(alpha: 0.7),
          ),
          const SizedBox(height: AppSpacing.md + 2),
          AppText(
            'Your watchlist is empty',
            textAlign: TextAlign.center,
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppText(
            'Star stocks from search or detail pages to track them here.',
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg + 2),
          Center(
            child: FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => StockSearchPage(
                    initialStocks: widget.stocks,
                    onSelected: widget.onStockTap,
                    onWatchlistChanged: () => unawaited(_loadWatchlist()),
                  ),
                ),
              ),
              icon: const Icon(Icons.search_rounded, size: 18),
              label: const AppText('Search stocks'),
            ),
          ),
        ],
      );
    }

    final list = _stockList(
      _watchlistStocks,
      emptyTitle: 'Your watchlist is empty',
      emptySubtitle: 'Add stocks from search or detail pages.',
      allowPagination: false,
      requireLogo: false,
    );
    if (!_watchlistFailed) return list;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Row(
            children: [
              const Icon(
                Icons.cloud_off_outlined,
                size: 20,
                color: AppColors.warning,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      'Watchlist could not be refreshed. Showing previously loaded stocks.',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.warning,
                      ),
                    ),
                    if (_watchlistState.updatedAt case final updatedAt?)
                      AppText(
                        'Last updated ${formatIstDateTime(updatedAt)}',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              TextButton(
                onPressed: _watchlistLoading
                    ? null
                    : () => unawaited(_loadWatchlist()),
                child: const AppText('Retry'),
              ),
            ],
          ),
        ),
        Expanded(child: list),
      ],
    );
  }
}
