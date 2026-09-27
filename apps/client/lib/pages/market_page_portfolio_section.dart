part of 'market_page.dart';

extension _MarketHomePortfolioSection on _MarketHomePageState {
  Widget _portfolioBody() => ProductPortfolioPage(
    onExplore: () => _onDestinationSelected(2),
    onNotifications: _openNotifications,
    notificationCount: unreadNotificationCount,
    onSearch: _openStockSearch,
  );

  Future<void> _loadPortfolioHistory(String period) async {
    final requestId = ++_portfolioHistoryRequest;
    final previousState = _portfolioHistoryState;
    final periodChanged = period != _portfolioPeriod;
    _updateState(() {
      _portfolioPeriod = period;
      _portfolioHistoryState = AsyncDataState.loading(
        data: periodChanged ? null : previousState.data,
        updatedAt: periodChanged ? null : previousState.updatedAt,
      );
    });
    try {
      final result = await ClientAccountService().assetHistory(period);
      if (!mounted || requestId != _portfolioHistoryRequest) return;
      final points = (result['points'] as List? ?? [])
          .whereType<Map>()
          .toList();
      final from = DateTime.tryParse(result['from']?.toString() ?? '');
      final history = _PortfolioHistoryData(
        series: points
            .map((point) => (point['totalValue'] as num).toDouble())
            .toList(),
        profit: (result['profitChange'] as num?)?.toDouble(),
        from: from?.toLocal().toString().substring(0, 16),
      );
      _updateState(() {
        _portfolioHistoryState = AsyncDataState.success(history);
      });
    } catch (error) {
      if (!mounted || requestId != _portfolioHistoryRequest) return;
      const message = 'History unavailable. Try again later.';
      _updateState(() {
        final previousHistory = _portfolioHistoryState.data;
        _portfolioHistoryState = previousHistory == null
            ? const AsyncDataState.error(message)
            : AsyncDataState.stale(
                previousHistory,
                updatedAt: _portfolioHistoryState.updatedAt ?? DateTime.now(),
                message: message,
              );
      });
    }
  }
}
