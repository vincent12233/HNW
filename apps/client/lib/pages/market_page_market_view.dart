part of 'market_page.dart';

extension _MarketHomeMarketView on _MarketHomePageState {
  Widget _marketBody() {
    double outstandingIpo = 0;
    double holdingsValue = 0;
    for (final application in ipoApplications) {
      if (application.status == IpoApplicationStatus.allocated &&
          application.remainingAmount > 0) {
        outstandingIpo += application.remainingAmount;
      }
    }
    for (final position in positions.values) {
      final stock = _stockForOrNull(
        position.symbol,
        exchange: position.exchange,
      );
      holdingsValue += position.marketValue(
        stock?.price ?? position.averageCost,
      );
    }
    final localTotalPortfolioValue = cashBalance + holdingsValue;
    final localUnrealizedPnl = positions.values.fold<double>(0, (
      total,
      position,
    ) {
      final stock = _stockForOrNull(
        position.symbol,
        exchange: position.exchange,
      );
      return total +
          position.unrealizedProfitLoss(stock?.price ?? position.averageCost);
    });
    final totalPortfolioValue =
        _authoritativeTotalAsset ?? localTotalPortfolioValue;
    final realizedPnl = realizedProfitLoss;
    final unrealizedPnl = _authoritativeUnrealizedPnl ?? localUnrealizedPnl;
    final vix =
        indexQuotes['INDIAVIX'] ??
        indexQuotes['INDIA VIX'] ??
        indexQuotes['VIX'];
    final quotes = latestQuoteUpdatedAt(stocks);
    final stale = quotesAreStale(stocks) || !marketConnected;
    return Container(
      color: AppColors.background,
      child: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            _refreshMarketData(),
            _refreshAccountSnapshot(),
            _reloadNews(),
          ]);
        },
        child: HomeDashboard(
          accountName: accountName,
          avatarBytes: profileAvatarBytes,
          onAvatarTap: () => unawaited(_pickProfileAvatar()),
          onSearch: _openStockSearch,
          onNotifications: () => unawaited(_openNotifications()),
          notificationCount: unreadNotificationCount,
          totalAssets: totalPortfolioValue,
          availableFunds: availableBalance,
          frozenFunds: frozenBalance,
          realizedPnl: realizedPnl,
          unrealizedPnl: unrealizedPnl,
          accountLoaded: _accountSnapshotLoaded,
          accountFailed: _accountSnapshotFailed,
          accountRefreshing: _accountSnapshotRefreshing,
          quotesLoading: isLoading,
          marketOpen: marketOpen,
          marketHours: marketHours,
          quotesConnected: marketConnected,
          hideBalances: _amountsHidden,
          onToggleHideBalances: () =>
              _updateState(() => _amountsHidden = !_amountsHidden),
          periodProfit: _periodProfit,
          periodLabel: _portfolioPeriod,
          periodLoading: _portfolioHistoryLoading,
          historyError: _historyError,
          historyFrom: _historyFrom,
          historyUpdatedAt: _portfolioHistoryState.updatedAt,
          portfolioSeries: _portfolioSeries,
          outstandingIpo: outstandingIpo,
          onSelectPeriod: (period) => unawaited(_loadPortfolioHistory(period)),
          indices: [
            HomeIndexQuote(
              label: 'NIFTY 50',
              price: nifty50Price,
              changePercent: nifty50Change,
              history: indexHistory['NIFTY 50'] ?? const <double>[],
            ),
            HomeIndexQuote(
              label: 'SENSEX',
              price: sensexPrice,
              changePercent: sensexChange,
              history: indexHistory['SENSEX'] ?? const <double>[],
            ),
            HomeIndexQuote(
              label: 'BANK NIFTY',
              price: bankNiftyPrice,
              changePercent: bankNiftyChange,
              history: indexHistory['BANK NIFTY'] ?? const <double>[],
            ),
            HomeIndexQuote(
              label: 'INDIA VIX',
              price: vix?.$1 ?? 0,
              changePercent: vix?.$2 ?? 0,
              history: indexHistory['INDIA VIX'] ?? const <double>[],
            ),
          ],
          gainers: homeTopMovers(stocks, gainers: true),
          losers: homeTopMovers(stocks, gainers: false),
          news: List<MarketNewsItem>.from(marketNews),
          featured: _homeFeatured,
          quoteUpdatedAt: quotes,
          quotesStale: stale,
          kycStatus: kycStatus,
          kycAvailable: !isLoading && accountPhone.isNotEmpty,
          onOpenKyc: () => unawaited(_openAccountSettings('kyc')),
          onDeposit: _openDepositSupport,
          onWithdraw: () => unawaited(_openWithdrawalRequest()),
          onTrade: () => _onDestinationSelected(2),
          onRetryAccount: () => unawaited(_refreshAccountSnapshot()),
          onRetryNews: () => unawaited(_reloadNews()),
          onRetryQuotes: () => unawaited(_refreshMarketData()),
          onOpenMarkets: () => _onDestinationSelected(1),
          onOpenNews: (item) => unawaited(_openNews(item)),
          onOpenStock: _openStock,
          onOpenIndex: _openHomeIndex,
          onViewAllNews: marketNews.isEmpty
              ? null
              : () => unawaited(_openAllMarketNews()),
          announcement: _homeAnnouncement == null
              ? null
              : HomeAnnouncementBanner(item: _homeAnnouncement!),
          companyCard: companyShowcases.isEmpty
              ? null
              : _companyShowcaseCard(companyShowcases.first),
          bottomPadding:
              SupportUiMetrics.of(context).fabBottom +
              AppSpacing.lg +
              (MediaQuery.textScalerOf(context).scale(1) > 1.2 ? 8 : 0),
        ),
      ),
    );
  }
}
