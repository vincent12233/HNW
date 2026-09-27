part of 'trading_center_page.dart';

extension _TradingCenterContentSection on _TradingCenterPageState {
  Widget _buildContent() {
    final missingOrders = _orders.isEmpty && [0, 4, 7].contains(selectedTab);
    final missingAccount = _positions.isEmpty && [0, 2].contains(selectedTab);
    if ((missingOrders || missingAccount) && _transactionsLoading) {
      return AppLoadingView(
        message: AppContentService.instance.current.text(
          'trading',
          'state.loading',
          fallback: 'Loading trading data',
        ),
      );
    }
    if ((missingOrders && _ordersFailed) ||
        (missingAccount && _accountFailed)) {
      return Center(
        child: AppText(
          AppContentService.instance.current.text(
            'trading',
            'state.data_unavailable',
            fallback: 'Trading data is temporarily unavailable.',
          ),
        ),
      );
    }
    switch (selectedTab) {
      case 0:
        return TradeList(
          orders: _orders,
          onViewOrders: () => _setState(() => selectedTab = 4),
          onCancel: _cancelStandardOrder,
          stocks: widget.stocks,
          positions: _positions,
          account: _accountSnapshot,
          onTrade: widget.onTrade,
          indexQuotes: widget.indexQuotes,
          onViewMarkets: widget.onViewMarkets,
        );
      case 1:
        return InstitutionalTab(
          stocks: widget.institutionalStocks,
          marketStocks: widget.stocks,
          onOpen: (stock) {
            StockQuote? match;
            for (final item in widget.stocks) {
              if (item.symbol.toUpperCase() == stock.symbol.toUpperCase() &&
                  item.exchange.toUpperCase() == stock.exchange.toUpperCase()) {
                match = item;
                break;
              }
            }
            final quote =
                match ??
                StockQuote(
                  stock.symbol,
                  stock.companyName,
                  stock.price > 0 ? stock.price : stock.marketPrice,
                  0,
                  0,
                  DateTime.now(),
                  exchange: stock.exchange,
                  category: 'INSTITUTIONAL',
                  quoteFresh: stock.price > 0 || stock.marketPrice > 0,
                );
            widget.onTrade(quote);
          },
        );
      case 2:
        return HoldingsTab(
          positions: _positions,
          stocks: widget.stocks,
          onSell: (stock, {required bool isBuy}) {
            widget.onOpenOrderTicket?.call(stock, isBuy: isBuy);
          },
        );
      case 3:
        return PendingCenterTab(
          activeOrders: _openAndPendingOrders,
          ipoApplications: widget.ipoApplications,
          applicationsFailed: widget.ipoApplicationsFailed,
          onRetryApplications: widget.onRetryIpos,
          onCancel: _cancelStandardOrder,
        );
      case 4:
        return OrdersTab(
          orders: _orders,
          onCancel: _cancelStandardOrder,
          loading: _transactionsLoading && _orders.isEmpty,
          failed: _ordersFailed,
          onRefresh: () => _refreshTradingData(ensureAfterCurrent: true),
        );
      case 5:
        return const OtcTab();
      case 6:
        return IpoTab(
          ipos: widget.ipos,
          applications: widget.ipoApplications,
          onApply: widget.onApplyIpo,
          loadFailed: widget.iposFailed,
          onRetry: widget.onRetryIpos,
        );
      case 7:
        return HistoryTab(
          orders: _orders,
          onRefresh: () => _refreshTradingData(ensureAfterCurrent: true),
        );
      case 8:
        return FundsTab(
          transactions: _transactions,
          loading: _transactionsLoading,
          loadFailed: _transactionsFailed,
          onRefresh: () => _refreshTradingData(ensureAfterCurrent: true),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
