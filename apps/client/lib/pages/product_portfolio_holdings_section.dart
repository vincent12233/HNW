part of 'product_portfolio_page.dart';

extension _ProductPortfolioHoldingsSection on _ProductPortfolioPageState {
  List<Widget> _productHoldings(
    List<Map<String, dynamic>> categories,
    dynamic asOf,
  ) {
    final positions = [
      for (final category in categories) ..._rows(category['positions']),
    ];
    if (positions.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          child: AppText(
            _portfolioCopy(
              'portfolio.no_holdings',
              'No product holdings in the current response.',
            ),
            style: AppTypography.bodyMedium,
          ),
        ),
      ];
    }
    return [
      Container(
        padding: const EdgeInsets.all(AppSpacing.xs),
        decoration: BoxDecoration(
          color: AppColors.surfaceSecondary,
          borderRadius: AppRadius.borderSm,
        ),
        child: Row(
          children: [
            for (final item in const [
              ('HOLDINGS', 'Holdings'),
              ('POSITIONS', 'Positions'),
            ])
              Expanded(
                child: ChoiceChip(
                  key: ValueKey('portfolio-view-${item.$1}'),
                  label: AppText(item.$2),
                  selected: _productView == item.$1,
                  onSelected: (_) => _updateState(() => _productView = item.$1),
                  selectedColor: AppColors.surface,
                  showCheckmark: false,
                  side: BorderSide.none,
                  labelStyle: AppTypography.labelSmall.copyWith(
                    color: _productView == item.$1
                        ? AppColors.brandPrimary
                        : AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.sm),
      AppStatusSwitch(
        switchKey: _productView,
        child: Column(
          children: [
            ...positions
                .take(4)
                .map((position) => _productPositionCard(position, asOf)),
          ],
        ),
      ),
      if (positions.length > 4)
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => _showHoldings(categories),
            child: AppText(
              _portfolioCopy('portfolio.view_details', 'View Details'),
            ),
          ),
        ),
    ];
  }

  Widget _productPositionCard(Map<String, dynamic> position, dynamic asOf) {
    final quantity = _availableNumber(position['quantity']);
    final available = _availableNumber(position['availableQuantity']);
    final frozen = quantity != null && available != null
        ? (quantity - available).clamp(0, quantity)
        : null;
    final costValued = position['valuationSource'] == 'COST';
    return AppCard(
      key: ValueKey('product-holding-${position['symbol']}'),
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      onTap: () => _showPositionSheet(position, asOf),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(
            '${position['symbol'] ?? '--'} · ${position['exchange'] ?? '--'}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.titleSmall.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          AppText(
            '${position['name'] ?? '--'}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.caption,
          ),
          const SizedBox(height: AppSpacing.sm),
          AppText(
            _productView == 'POSITIONS'
                ? 'Frozen ${frozen == null
                      ? '--'
                      : _hidden
                      ? '******'
                      : '${frozen.toInt()}'} · Avail ${_quantity(position['availableQuantity'])} · Qty ${_quantity(position['quantity'])}'
                : 'Qty ${_quantity(position['quantity'])} · Avail ${_quantity(position['availableQuantity'])} · Frozen ${frozen == null
                      ? '--'
                      : _hidden
                      ? '******'
                      : '${frozen.toInt()}'}',
            style: AppTypography.bodySmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          _metrics([
            ('Average price', position['averagePrice']),
            ('Current Value', position['currentValue']),
            ('Unrealized P&L', position['unrealizedPnl']),
          ]),
          if (costValued)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: AppText(
                _portfolioCopy(
                  'portfolio.detail.valuation_cost',
                  'Valued at cost. Market quote unavailable.',
                ),
                style: AppTypography.caption.copyWith(color: AppColors.warning),
              ),
            ),
        ],
      ),
    );
  }

  void _showPositionSheet(Map<String, dynamic> position, dynamic asOf) {
    final quantity = _availableNumber(position['quantity']);
    final available = _availableNumber(position['availableQuantity']);
    final frozen = quantity != null && available != null
        ? (quantity - available).clamp(0, quantity)
        : null;
    final content = AppContentService.instance.current;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.sm,
            AppSpacing.xl,
            AppSpacing.xxl,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  '${position['symbol'] ?? '--'}',
                  style: AppTypography.headline.copyWith(fontSize: 20),
                ),
                AppText(
                  '${position['name'] ?? '--'} · ${position['exchange'] ?? '--'}',
                ),
                const SizedBox(height: AppSpacing.lg),
                AppText(
                  '${content.text('trading', 'portfolio.detail.quantity', fallback: 'Quantity')}: ${_quantity(position['quantity'])}',
                ),
                AppText(
                  '${content.text('trading', 'portfolio.detail.available', fallback: 'Available')}: ${_quantity(position['availableQuantity'])}',
                ),
                AppText(
                  '${content.text('trading', 'portfolio.detail.frozen', fallback: 'Frozen')}: ${frozen == null
                      ? '--'
                      : _hidden
                      ? '******'
                      : '${frozen.toInt()}'}',
                ),
                AppText(
                  '${content.text('trading', 'portfolio.detail.average_cost', fallback: 'Average cost')}: ${_money(position['averagePrice'])}',
                ),
                AppText(
                  '${content.text('trading', 'portfolio.detail.current_price', fallback: 'Current price')}: ${position['valuationSource'] == 'COST' ? 'Unavailable' : _money(position['currentPrice'])}',
                ),
                AppText(
                  '${content.text('trading', 'portfolio.detail.current_value', fallback: 'Current value')}: ${_money(position['currentValue'])}',
                ),
                AppText(
                  '${content.text('trading', 'portfolio.detail.invested', fallback: 'Invested')}: ${quantity == null || _availableNumber(position['averagePrice']) == null ? '--' : _money(quantity * _number(position['averagePrice']))}',
                ),
                AppText(
                  '${content.text('trading', 'portfolio.detail.realized_pnl', fallback: 'Realized P&L')}: ${_availableNumber(position['realizedPnl']) == null ? 'Unavailable' : _pnlText(position['realizedPnl'])}',
                ),
                AppText(
                  '${content.text('trading', 'portfolio.detail.unrealized_pnl', fallback: 'Unrealized P&L')}: ${_pnlText(position['unrealizedPnl'])}',
                ),
                AppText(
                  '${content.text('trading', 'portfolio.detail.day_pnl', fallback: 'Day P&L')}: Unavailable',
                ),
                const SizedBox(height: AppSpacing.md),
                AppText(
                  position['valuationSource'] == 'COST'
                      ? content.text(
                          'trading',
                          'portfolio.detail.valuation_cost',
                          fallback: 'Valued at cost. Market quote unavailable.',
                        )
                      : content.text(
                          'trading',
                          'portfolio.detail.valuation_market',
                          fallback:
                              'Valued from the current market quote in this response.',
                        ),
                  style: AppTypography.caption,
                ),
                AppText(
                  '${tr('As of')} ${_date(asOf)}',
                  style: AppTypography.caption,
                ),
                const SizedBox(height: AppSpacing.sm),
                AppText(
                  _portfolioCopy(
                    'portfolio.related_fills_note',
                    'Related fills are not included in this product holding record.',
                  ),
                  style: AppTypography.caption,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
