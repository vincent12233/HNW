part of 'markets_page.dart';

extension _MarketsStockListSection on _MarketsPageState {
  Widget _stockList(
    List<StockQuote> stocks, {
    required String emptyTitle,
    String emptySubtitle = 'Try a different search or market filter.',
    bool allowPagination = true,
    bool requireLogo = true,
    String? browseOnlyLabel,
  }) {
    stocks = stocks
        .where(
          (stock) =>
              !requireLogo ||
              (stock.logoUrl?.trim().isNotEmpty == true &&
                  !_failedLogoUrls.contains(stock.logoUrl)),
        )
        .toList();
    Widget wrapBrowse(Widget child) {
      if (browseOnlyLabel == null) return child;
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: BrowseOnlyBanner(productLabel: browseOnlyLabel),
          ),
          Expanded(child: child),
        ],
      );
    }

    if (_searchLoading && stocks.isEmpty) {
      return wrapBrowse(
        AppLoadingView(
          message: _marketCopy('markets.loading', 'Loading markets…'),
        ),
      );
    }
    if (allowPagination && _searchFailed && stocks.isEmpty) {
      return wrapBrowse(
        _emptyState(
          Icons.cloud_off,
          _marketCopy('markets.search_error_title', 'Market data unavailable'),
          _marketCopy(
            'markets.search_error_body',
            'Network error or live search is unavailable. Please refresh to try again.',
          ),
        ),
      );
    }
    if (stocks.isEmpty && !(allowPagination && _searchHasMore)) {
      return wrapBrowse(
        _emptyState(
          Icons.search_off,
          emptyTitle,
          requireLogo
              ? '$emptySubtitle Only stocks with available logos are shown. Refresh to retry.'
              : emptySubtitle,
        ),
      );
    }

    final showMore = allowPagination && (_searchHasMore || _searchFailed);
    return wrapBrowse(
      ListView.separated(
        key: PageStorageKey('market-list-$selectedTab'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: AppSpacing.page,
        itemCount: stocks.length + (showMore ? 1 : 0),
        separatorBuilder: (_, _) =>
            const Divider(height: 1, color: AppColors.divider),
        itemBuilder: (context, index) {
          if (index == stocks.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Center(
                child: OutlinedButton(
                  onPressed: _searchLoading
                      ? null
                      : () => _searchStocks(
                          reset: _searchFailed && _failedSearchWasReset,
                        ),
                  child: _searchLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            semanticsLabel: 'Loading more stocks',
                          ),
                        )
                      : AppText(
                          _searchFailed
                              ? _marketCopy(
                                  'markets.load_more_retry',
                                  'Unable to load stocks. Retry',
                                )
                              : _marketCopy('markets.load_more', 'Load more'),
                        ),
                ),
              ),
            );
          }

          final stock = stocks[index];
          return StockListTile(
            key: ValueKey('${stock.exchange}:${stock.symbol}:${stock.logoUrl}'),
            stock: stock,
            onLogoLoadFailed: () {
              if (!mounted ||
                  stock.logoUrl == null ||
                  _failedLogoUrls.contains(stock.logoUrl)) {
                return;
              }
              _updateState(() => _failedLogoUrls.add(stock.logoUrl!));
            },
            onTap: () {
              widget.onStockTap(stock);
            },
          );
        },
      ),
    );
  }
}