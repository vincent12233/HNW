part of 'stock_detail_page.dart';

extension _StockDetailOrderSection on _StockDetailPageState {
  Future<void> placeOrder() async {
    if (_browseOnly) return;
    final quantity = int.tryParse(quantityController.text) ?? 0;
    final limitPrice = isLimit
        ? double.tryParse(limitPriceController.text.trim())
        : null;

    if (quantity <= 0) {
      _showMessage('Please enter a valid quantity');
      return;
    }
    if (isLimit && (limitPrice == null || limitPrice <= 0)) {
      _showMessage('Please enter a valid limit price');
      return;
    }
    if (!orderQuoteReady) {
      _showMessage('Current market quote is unavailable. Please refresh.');
      marketSocket.refreshSnapshot();
      return;
    }

    final quoteDelayed =
        !socketConnected ||
        !liveStock.quoteFresh ||
        DateTime.now().difference(liveStock.updatedAt) >
            const Duration(minutes: 2);
    final riskNotice = [
      if (widget.marketOpen == false)
        'The exchange session is closed. Confirm stays disabled until the market is open. The server still verifies session state.',
      if (quoteDelayed)
        'Market price may be delayed. Review the order price before confirming.',
    ].join('\n\n');

    String? successMessage;
    TradingOrder? confirmedOrder;

    await showOrderConfirmDialog(
      context: context,
      stock: liveStock,
      isBuy: isBuy,
      orderType: orderType,
      timeInForce: timeInForce,
      quantity: quantity,
      estimatedAmount: estimatedAmount,
      limitPrice: isLimit ? limitPrice : null,
      marketOpen: widget.marketOpen,
      marketHours: widget.marketHours,
      riskNotice: riskNotice.isEmpty ? null : riskNotice,
      onConfirm: () async {
        if (isSubmitting) {
          return 'Order is already being submitted.';
        }
        _setState(() => isSubmitting = true);
        final draft = TradingOrder(
          symbol: liveStock.symbol,
          exchange: liveStock.exchange,
          isBuy: isBuy,
          quantity: quantity,
          price: selectedOrderPrice,
          placedAt: DateTime.now(),
          type: orderType,
          timeInForce: timeInForce,
          limitPrice: limitPrice,
        );
        final fingerprint = draft.submissionFingerprint();
        if (_pendingOrderFingerprint != fingerprint) {
          _pendingClientOrderId = null;
          _pendingOrderFingerprint = fingerprint;
        }
        _pendingClientOrderId ??= TradingService.createClientOrderId(
          exchange: draft.exchange,
          symbol: draft.symbol,
        );
        final order = draft.withClientOrderId(_pendingClientOrderId!);

        TradingService.clearLastPlacedOrder();
        final String? errorMessage;
        try {
          errorMessage = await widget.onOrderPlaced(order);
        } catch (_) {
          if (mounted) _setState(() => isSubmitting = false);
          return 'Order placement failed';
        }
        confirmedOrder =
            TradingService.takeLastPlacedOrder() ??
            StockDetailPage.debugNextConfirmedOrder;
        StockDetailPage.debugNextConfirmedOrder = null;

        if (!mounted) return errorMessage;
        _setState(() => isSubmitting = false);

        if (errorMessage != null) {
          return errorMessage;
        }

        _pendingClientOrderId = null;
        _pendingOrderFingerprint = null;
        successMessage = confirmedOrder == null
            ? '${isBuy ? 'Buy' : 'Sell'} ${isLimit ? 'limit' : 'market'} order submitted'
            : orderResultMessage(confirmedOrder!);
        return null;
      },
    );

    if (successMessage != null) {
      _showMessage(successMessage!, order: confirmedOrder);
    }
  }

  void _showMessage(String message, {TradingOrder? order}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: AppText(message),
          action: order == null
              ? null
              : SnackBarAction(
                  label: 'View Order',
                  onPressed: () => _showOrderDetails(order),
                ),
        ),
      );
  }

  void _showOrderDetails(TradingOrder order) {
    if (!mounted) return;
    showStandardOrderDetails(context, order: order);
  }

}
