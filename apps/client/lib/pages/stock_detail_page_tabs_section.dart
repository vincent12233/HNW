part of 'stock_detail_page.dart';

extension _StockDetailTabsSection on _StockDetailPageState {
  Widget _overviewTab() {
    return SingleChildScrollView(
      key: const Key('stock-overview'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_browseOnly) ...[
            const BrowseOnlyBanner(),
            const SizedBox(height: 12),
          ],
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _marketStat(
                          'Best Bid',
                          _statPrice(liveStock.bid),
                        ),
                      ),
                      Expanded(
                        child: _marketStat(
                          'Best Ask',
                          _statPrice(liveStock.ask),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: _marketStat('Open', _statPrice(liveStock.open)),
                      ),
                      Expanded(
                        child: _marketStat(
                          'Prev. Close',
                          _statPrice(liveStock.previousClose),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: _marketStat(
                          "Day's High",
                          _statPrice(liveStock.high),
                        ),
                      ),
                      Expanded(
                        child: _marketStat(
                          "Day's Low",
                          _statPrice(liveStock.low),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: _marketStat(
                          'Volume',
                          _formatVolume(liveStock.volume),
                        ),
                      ),
                      Expanded(child: _marketStat('Symbol', liveStock.symbol)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_hasMarketRangeData) ...[
            const SizedBox(height: 12),
            _marketRangeCard(),
          ],
          const SizedBox(height: 18),
          if (!_browseOnly) ...[
            OrderTicketPanel(
              stock: liveStock,
              isBuy: isBuy,
              orderType: orderType,
              timeInForce: timeInForce,
              quantityController: quantityController,
              limitPriceController: limitPriceController,
              account: accountSnapshot,
              marketOpen: widget.marketOpen,
              marketHours: widget.marketHours,
              quotesConnected: widget.quotesConnected ?? socketConnected,
              quantityError: quantityError,
              priceError: priceError,
              onBuyChanged: (value) => _setState(() {
                isBuy = value;
                _pendingClientOrderId = null;
                _pendingOrderFingerprint = null;
              }),
              onOrderTypeChanged: (value) => _setState(() {
                orderType = value;
                _pendingClientOrderId = null;
                _pendingOrderFingerprint = null;
                if (orderType == 'LIMIT' &&
                    limitPriceController.text.trim().isEmpty) {
                  limitPriceController.text = liveStock.price.toStringAsFixed(
                    2,
                  );
                }
              }),
              onTimeInForceChanged: (value) => _setState(() {
                timeInForce = value;
                _pendingClientOrderId = null;
                _pendingOrderFingerprint = null;
              }),
              onChanged: () => _setState(() {}),
            ),
            const SizedBox(height: 16),
            OrderEstimateCard(
              stock: liveStock,
              isBuy: isBuy,
              isLimit: isLimit,
              quantity: int.tryParse(quantityController.text) ?? 0,
              selectedPrice: selectedOrderPrice,
              estimatedAmount: estimatedAmount,
              account: accountSnapshot,
              maxQuantity: isBuy ? maxBuyQuantity : availableSellQuantity,
              deviationPercent: limitDeviationPercent,
              quoteReady: orderQuoteReady,
              onUseMax: () {
                final maxQuantity = isBuy
                    ? maxBuyQuantity
                    : availableSellQuantity;
                if (maxQuantity == null || maxQuantity <= 0) return;
                quantityController.text = '$maxQuantity';
                _setState(() {});
              },
            ),
            const SizedBox(height: 8),
            AppText(
              'Use Buy / Sell below to review the order. Confirm is required before it is sent.',
              style: TextStyle(
                color: AppConfig.textSecondaryColor.withValues(alpha: 0.9),
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _chartTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        StockHistoryChart(
          symbol: liveStock.symbol,
          exchange: liveStock.exchange,
          latestPrice: liveStock.price,
          latestAt: liveStock.updatedAt,
          previousClose: liveStock.previousClose,
        ),
      ],
    );
  }

  Widget _newsTab() {
    if (newsLoading) {
      return const Center(
        child: CircularProgressIndicator(semanticsLabel: 'Loading news'),
      );
    }
    if (newsFailed) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppText(
                'News could not be loaded. Please try again.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _loadRelatedNews,
                child: const AppText('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (relatedNews.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: AppText(
            'No verified headlines currently mention this stock.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: relatedNews.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = relatedNews[index];
        return AppCard(
          padding: const EdgeInsets.all(14),
          onTap: () => showMarketNewsSheet(
            context: context,
            item: item,
            onOpen: _openNews,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(
                item.title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              AppText(
                item.source,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _eventsTab() {
    if (yearHistoryFailed &&
        (yearHistory == null || yearHistory!.events.isEmpty)) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppText(
                'Corporate events could not be loaded. Please try again.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _loadYearStats,
                child: const AppText('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    final events = yearHistory?.events ?? const [];
    if (events.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: AppText(
            'No dividend or split events were returned for this range.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: events.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final event = events[index];
        return AppCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(
                event.type == 'SPLIT' ? 'Split' : 'Dividend',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              AppText(
                DateFormat('yyyy-MM-dd').format(event.date.toLocal()),
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
              if (event.label.isNotEmpty) ...[
                const SizedBox(height: 6),
                AppText(event.label),
              ],
              if (event.value > 0) ...[
                const SizedBox(height: 6),
                AppText(
                  event.value.toString(),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

}
