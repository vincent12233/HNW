import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../l10n/app_language.dart';
import '../services/app_content_service.dart';
import '../services/client_account_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_radius.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/client_error_message.dart';
import '../utils/number_formatters.dart';
import '../widgets/app_card.dart';
import '../widgets/app_page_scaffold.dart';

class ProductPortfolioPage extends StatefulWidget {
  const ProductPortfolioPage({
    super.key,
    required this.onExplore,
    required this.onNotifications,
    this.notificationCount = 0,
    this.onSearch,
    this.loader,
  });
  final VoidCallback onExplore;
  final VoidCallback onNotifications;
  final int notificationCount;
  final VoidCallback? onSearch;
  final Future<Map<String, dynamic>> Function(String period)? loader;
  @override
  State<ProductPortfolioPage> createState() => _ProductPortfolioPageState();
}

class _ProductPortfolioPageState extends State<ProductPortfolioPage> {
  String _portfolioCopy(String key, String fallback) => AppContentService
      .instance
      .current
      .text('trading', key, fallback: fallback);

  Map<String, dynamic>? _data;
  String? _error;
  String _period = '1M';
  bool _loading = false;
  bool _hidden = false;
  int _request = 0;
  String _productView = 'HOLDINGS';

  static Color _categoryColor(Object? category) {
    switch ('$category') {
      case 'Institutional':
        return AppColors.brandPrimary;
      case 'OTC':
        return AppColors.gain;
      case 'IPO':
        return AppColors.warning;
      default:
        return AppColors.neutral;
    }
  }

  @override
  void initState() {
    super.initState();
    AppContentService.instance.addListener(_onContentChanged);
    _load();
  }

  void _onContentChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    AppContentService.instance.removeListener(_onContentChanged);
    super.dispose();
  }

  Future<void> _load([String? period]) async {
    if (_loading && (period == null || period == _period)) return;
    final request = ++_request;
    setState(() {
      if (period != null && period != _period) _data = null;
      _period = period ?? _period;
      _loading = true;
      _error = null;
    });
    try {
      final data =
          await (widget.loader ?? ClientAccountService().productPortfolio)(
            _period,
          );
      if (mounted && request == _request) setState(() => _data = data);
    } catch (error) {
      if (mounted && request == _request) {
        setState(() => _error = clientErrorMessage(error));
      }
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  Future<void> _refreshAll() async {
    await Future.wait([AppContentService.instance.load(force: true), _load()]);
  }

  double _number(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
  double? _availableNumber(dynamic value) {
    final number = value is num ? value.toDouble() : double.tryParse('$value');
    return number != null && number.isFinite ? number : null;
  }

  List<Map<String, dynamic>> _rows(dynamic value) =>
      (value is List ? value : const [])
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
  String _money(dynamic value) => _hidden
      ? '******'
      : _availableNumber(value) == null
      ? '--'
      : formatPrice(_number(value));
  String _percent(dynamic value) => _hidden
      ? '******'
      : _availableNumber(value) == null
      ? '--'
      : '${_number(value).toStringAsFixed(1)}%';
  String _quantity(dynamic value) => _hidden
      ? '******'
      : _availableNumber(value) == null
      ? '--'
      : '$value';

  String _frozenText(Map<String, dynamic> position) {
    final quantity = _availableNumber(position['quantity']);
    final available = _availableNumber(position['availableQuantity']);
    if (quantity == null || available == null) return '--';
    if (_hidden) return '******';
    return '${(quantity - available).clamp(0, quantity).toInt()}';
  }

  String _date(dynamic value) {
    final parsed = DateTime.tryParse('$value');
    if (parsed == null) return '--';
    return formatIstDateTime(parsed);
  }

  String _signed(dynamic value) {
    if (_hidden) return '******';
    final number = _availableNumber(value);
    return number == null ? '--' : formatSignedPrice(number);
  }

  String _pnlWord(dynamic value) {
    if (_hidden) return '';
    final number = _availableNumber(value);
    if (number == null) return '';
    if (number > 0) return 'Gain';
    if (number < 0) return 'Loss';
    return 'Unchanged';
  }

  String _pnlText(dynamic value) {
    final word = _pnlWord(value);
    final amount = _signed(value);
    return word.isEmpty ? amount : '$amount · $word';
  }

  Color _pnlColor(dynamic value) => _hidden || _number(value) == 0
      ? AppColors.textSecondary
      : _number(value) > 0
      ? AppColors.gain
      : AppColors.loss;

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: RefreshIndicator(
          onRefresh: _refreshAll,
          child: ListView(
            key: const Key('portfolio-list'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: AppSpacing.page,
            children: [
              Row(
                children: [
                  Expanded(
                    child: AppText(
                      AppContentService.instance.current.text(
                        'trading',
                        'portfolio.page_title',
                        fallback: 'Portfolio',
                      ),
                      style: AppTypography.headline.copyWith(fontSize: 20),
                    ),
                  ),
                  if (widget.onSearch != null)
                    IconButton(
                      tooltip: tr('Search stocks'),
                      onPressed: widget.onSearch,
                      icon: const Icon(Icons.search_rounded),
                    ),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IconButton(
                        tooltip: widget.notificationCount > 0
                            ? '${tr('Notifications')} (${widget.notificationCount})'
                            : tr('Notifications'),
                        onPressed: widget.onNotifications,
                        icon: const Icon(Icons.notifications_none_rounded),
                      ),
                      if (widget.notificationCount > 0)
                        Positioned(
                          right: 8,
                          top: 7,
                          child: IgnorePointer(
                            child: Container(
                              width: 17,
                              height: 17,
                              alignment: Alignment.center,
                              decoration: const BoxDecoration(
                                color: AppColors.loss,
                                shape: BoxShape.circle,
                              ),
                              child: AppText(
                                widget.notificationCount > 9
                                    ? '9+'
                                    : widget.notificationCount.toString(),
                                textScaler: TextScaler.noScaling,
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.textInverse,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              if (_loading && data != null)
                const LinearProgressIndicator(minHeight: 2),
              if (_loading && data == null)
                Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: AppSpacing.sectionGap,
                  ),
                  child: Column(
                    children: [
                      CircularProgressIndicator(
                        semanticsLabel: _portfolioCopy(
                          'portfolio.loading',
                          'Loading portfolio',
                        ),
                      ),
                      SizedBox(height: AppSpacing.md),
                      AppText(
                        _portfolioCopy(
                          'portfolio.loading',
                          'Loading portfolio',
                        ),
                      ),
                    ],
                  ),
                ),
              if (_error != null && data == null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
                  child: AppEmptyState(
                    title: _portfolioCopy(
                      'portfolio.load_error_title',
                      'Unable to load portfolio',
                    ),
                    message: _error,
                    icon: Icons.wifi_off_outlined,
                    onRetry: _loading ? null : _load,
                  ),
                ),
              if (_error != null && data != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.md + 2,
                  ),
                  child: Semantics(
                    liveRegion: true,
                    child: AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppText(
                            _portfolioCopy(
                              'portfolio.stale_data',
                              'Showing previously loaded portfolio data.',
                            ),
                            style: AppTypography.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          AppText(_error!, style: AppTypography.bodySmall),
                          TextButton.icon(
                            onPressed: _loading ? null : _load,
                            icon: const Icon(Icons.refresh),
                            label: AppText(tr('Retry')),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (data != null)
                AppFadeIn(
                  switchKey:
                      '$_period|${data['asOf']}|${data['positionCount']}',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _content(data),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _content(Map<String, dynamic> data) {
    final categories = _rows(data['categories']);
    final history = data['history'] is Map
        ? Map<String, dynamic>.from(data['history'])
        : <String, dynamic>{};
    final points = _rows(history['points']);
    final empty = _availableNumber(data['positionCount']) == 0;
    final hasHistory =
        points.length >= 2 &&
        points.every(
          (point) => _availableNumber(point['productValue']) != null,
        );
    final inverseMuted = AppColors.textInverse.withValues(alpha: 0.7);
    return [
      const SizedBox(height: AppSpacing.md),
      // PRIMARY: hero Total Portfolio Value + Total Returns + period/sparkline
      Container(
        padding: const EdgeInsets.all(AppSpacing.md + 2),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.brandPrimary, AppColors.brandGradientEnd],
          ),
          borderRadius: AppRadius.borderMd,
          border: Border.all(color: Colors.white24),
          boxShadow: AppShadows.brandHero,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: AppText(
                    _portfolioCopy(
                      'portfolio.value_label',
                      'Total Portfolio Value',
                    ),
                    style: AppTypography.bodyMedium.copyWith(
                      color: inverseMuted,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: tr(_hidden ? 'Show balances' : 'Hide balances'),
                  onPressed: () => setState(() => _hidden = !_hidden),
                  icon: Icon(
                    _hidden
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: inverseMuted,
                    size: 20,
                  ),
                ),
              ],
            ),
            AppText(
              _money(data['currentValue']),
              style: AppTypography.numericInverse.copyWith(fontSize: 24),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppText(
              key: const ValueKey('portfolio-hero-returns'),
              '${tr('Total Returns')}: ${_pnlText(data['totalPnl'])}',
              style: AppTypography.bodyMedium.copyWith(
                color: _hidden || _number(data['totalPnl']) == 0
                    ? inverseMuted
                    : _number(data['totalPnl']) > 0
                    ? AppColors.chartGain
                    : const Color(0xFFFFB4B4),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (!empty && !_hidden)
              SizedBox(
                height: 64,
                width: double.infinity,
                child: AppStatusSwitch(
                  switchKey: '$_period|$hasHistory|$_loading',
                  child: _loading
                      ? Center(
                          child: CircularProgressIndicator(
                            color: AppColors.textInverse,
                            strokeWidth: 2,
                            semanticsLabel: tr('Loading performance'),
                          ),
                        )
                      : !hasHistory
                      ? Center(
                          child: AppText(
                            _portfolioCopy(
                              'portfolio.insufficient_history',
                              'Insufficient history',
                            ),
                            style: AppTypography.bodyMedium.copyWith(
                              color: inverseMuted,
                            ),
                          ),
                        )
                      : CustomPaint(
                          key: const ValueKey('portfolio-history-chart'),
                          painter: _ValueHistoryPainter(
                            points
                                .map((row) => _number(row['productValue']))
                                .toList(),
                          ),
                        ),
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final period in ['1D', '1W', '1M', '3M', '1Y', 'All'])
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.xs),
                      child: ChoiceChip(
                        key: ValueKey('portfolio-period-$period'),
                        label: AppText(period),
                        selected: _period == period,
                        onSelected: (_) {
                          if (period != _period) _load(period);
                        },
                        showCheckmark: false,
                        selectedColor: AppColors.textInverse,
                        backgroundColor: Colors.white10,
                        side: BorderSide(
                          color: _period == period
                              ? Colors.transparent
                              : Colors.white12,
                        ),
                        visualDensity: VisualDensity.compact,
                        labelStyle: AppTypography.labelSmall.copyWith(
                          fontSize: 10,
                          color: _period == period
                              ? AppColors.brandDark
                              : inverseMuted,
                        ),
                        labelPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                        ),
                        shape: const StadiumBorder(),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.lg + 2),
      // SECONDARY: Investment Summary metrics in AppCard
      _datedHeading(
        AppContentService.instance.current.text(
          'trading',
          'portfolio.summary_heading',
          fallback: 'Investment Summary',
        ),
        '${tr('As of')} ${_date(data['asOf'])}',
      ),
      const SizedBox(height: AppSpacing.md),
      AppCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md + 2,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _metrics([
              ('Invested', data['invested']),
              ('Current Value', data['currentValue']),
              ('Total Returns', data['totalPnl']),
            ]),
          ],
        ),
      ),
      if (empty) ...[
        const SizedBox(height: AppSpacing.sectionGap),
        SizedBox(
          height: 280,
          child: AppEmptyState(
            icon: Icons.account_balance_outlined,
            title: AppContentService.instance.current.text(
              'trading',
              'portfolio.empty_title',
              fallback: 'No investments yet',
            ),
            message: AppContentService.instance.current.text(
              'trading',
              'portfolio.empty_subtitle',
              fallback: 'No Institutional, OTC or IPO holdings yet.',
            ),
          ),
        ),
        Center(
          child: FilledButton.icon(
            onPressed: widget.onExplore,
            icon: const Icon(Icons.arrow_forward),
            label: AppText(
              AppContentService.instance.current.text(
                'trading',
                'portfolio.explore_cta',
                fallback: 'Explore offers',
              ),
            ),
          ),
        ),
      ] else ...[
        const SizedBox(height: AppSpacing.sectionGap),
        // DETAIL: Asset Allocation
        _heading(
          AppContentService.instance.current.text(
            'trading',
            'portfolio.allocation_heading',
            fallback: 'Asset Allocation',
          ),
          action: () => _showHoldings(categories),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final legend = Column(
                children: categories
                    .map(
                      (category) => Semantics(
                        button: true,
                        label:
                            '${tr(category['category'].toString())}, '
                            '${tr('Current Value')} ${_money(category['currentValue'])}, '
                            '${tr('Allocation')} ${_percent(category['allocationPercent'])}',
                        child: ExcludeSemantics(
                          child: InkWell(
                            onTap: () => _showHoldings([category]),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.sm + 2,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.circle,
                                    size: 9,
                                    color: _categoryColor(category['category']),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        AppText(
                                          tr(category['category'].toString()),
                                          style: AppTypography.labelSmall,
                                        ),
                                        const SizedBox(height: AppSpacing.xs),
                                        AppText(
                                          _money(category['currentValue']),
                                          style: AppTypography.numericSmall
                                              .copyWith(fontSize: 10),
                                        ),
                                        const SizedBox(height: AppSpacing.xs),
                                        if (!_hidden &&
                                            _availableNumber(
                                                  category['allocationPercent'],
                                                ) !=
                                                null)
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              3,
                                            ),
                                            child: LinearProgressIndicator(
                                              value:
                                                  (_number(
                                                            category['allocationPercent'],
                                                          ) /
                                                          100)
                                                      .clamp(0.0, 1.0),
                                              minHeight: 3,
                                              color: _categoryColor(
                                                category['category'],
                                              ),
                                              backgroundColor:
                                                  AppColors.surfaceSecondary,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  AppText(
                                    _percent(category['allocationPercent']),
                                    style: AppTypography.numericSmall,
                                  ),
                                  const SizedBox(width: AppSpacing.xs),
                                  const Icon(Icons.chevron_right, size: 18),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              );
              final donut = Semantics(
                image: true,
                label:
                    '${_portfolioCopy('portfolio.allocation_heading', 'Asset Allocation')}, '
                    '${tr('Current Value')} ${_money(data['currentValue'])}, 100%',
                child: ExcludeSemantics(
                  child: SizedBox.square(
                    dimension: 128,
                    child: CustomPaint(
                      painter: _AllocationPainter(
                        categories
                            .map((c) => _number(c['currentValue']))
                            .toList(),
                        categories
                            .map((c) => _categoryColor(c['category']))
                            .toList(),
                      ),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.lg + 2),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: AppText(
                                  _money(data['currentValue']),
                                  style: AppTypography.numericSmall.copyWith(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              AppText(
                                '100%',
                                style: AppTypography.caption.copyWith(
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
              if (_hidden ||
                  _number(data['currentValue']) <= 0 ||
                  categories.any(
                    (category) =>
                        _availableNumber(category['currentValue']) == null,
                  )) {
                return legend;
              }
              if (constraints.maxWidth < 320 ||
                  MediaQuery.textScalerOf(context).scale(1) > 1.2) {
                return Column(
                  children: [
                    donut,
                    const SizedBox(height: AppSpacing.md - 2),
                    legend,
                  ],
                );
              }
              return Row(
                children: [
                  donut,
                  const SizedBox(width: AppSpacing.md + 2),
                  Expanded(child: legend),
                ],
              );
            },
          ),
        ),
        // DETAIL: Asset Details
        _heading(
          _portfolioCopy('portfolio.asset_details_heading', 'Asset Details'),
        ),
        const SizedBox(height: AppSpacing.sm),
        ...categories.map(
          (category) => AppCard(
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            borderColor: AppColors.divider,
            shadow: AppCardShadow.small,
            onTap: () => _showHoldings([category]),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: _categoryColor(category['category']),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Icon(
                        category['category'] == 'OTC'
                            ? Icons.verified_user_outlined
                            : category['category'] == 'IPO'
                            ? Icons.rocket_launch_outlined
                            : Icons.account_balance_outlined,
                        color: AppColors.textInverse,
                        size: 17,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md - 2),
                    Expanded(
                      child: AppText(
                        tr(category['category'].toString()),
                        style: AppTypography.titleSmall,
                      ),
                    ),
                    const Icon(Icons.chevron_right, size: 20),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm - 2),
                _metrics([
                  ('Current Value', category['currentValue']),
                  ('Allocation', category['allocationPercent']),
                  ('Invested', category['invested']),
                  ('Total Returns', category['totalPnl']),
                ]),
                if (!_hidden &&
                    _availableNumber(category['allocationPercent']) !=
                        null) ...[
                  const SizedBox(height: AppSpacing.md - 2),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: (_number(category['allocationPercent']) / 100)
                          .clamp(0.0, 1.0),
                      minHeight: 4,
                      color: _categoryColor(category['category']),
                      backgroundColor: AppColors.surfaceSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _heading(
          _portfolioCopy(
            'portfolio.holdings_heading',
            'Holdings and Positions',
          ),
        ),
        AppText(
          _portfolioCopy(
            'portfolio.holdings_caption',
            'Product holdings from the current portfolio response. Equity positions remain under Trade.',
          ),
          style: AppTypography.caption,
        ),
        const SizedBox(height: AppSpacing.sm),
        ..._productHoldings(categories, data['asOf']),
        const SizedBox(height: AppSpacing.md),
        // DETAIL: Performance
        _heading(
          _portfolioCopy('portfolio.performance_heading', 'Performance'),
          action: () => _showPerformance(data, history),
        ),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md + 2,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _metrics([
                ('Unrealized P&L', data['unrealizedPnl']),
                ('Realized P&L', data['realizedPnl']),
                (
                  'Recorded P&L',
                  _loading ? null : history['productProfitChange'],
                ),
              ]),
              const SizedBox(height: AppSpacing.md),
              AppText(
                '${tr('Best Segment')}: ${_hidden ? '******' : tr(data['bestSegment']?.toString() ?? '--')}',
                style: AppTypography.labelLarge,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        // DETAIL: Recent Activity
        _heading(
          _portfolioCopy('portfolio.recent_activity', 'Recent Activity'),
          action: () => _showActivity(_rows(data['activity'])),
        ),
        if (_rows(data['activity']).isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
            child: Center(
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.brandPrimarySoft,
                      borderRadius: AppRadius.borderSm,
                    ),
                    child: const Icon(
                      Icons.history_rounded,
                      color: AppColors.brandPrimary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppText(
                    _portfolioCopy(
                      'portfolio.no_activity',
                      'No product activity yet',
                    ),
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ..._rows(data['activity']).take(5).map(_activityTile),
      ],
      const SizedBox(height: AppSpacing.xxl),
    ];
  }

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
                  onSelected: (_) => setState(() => _productView = item.$1),
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

  Widget _heading(String title, {VoidCallback? action}) => LayoutBuilder(
    builder: (context, constraints) {
      final heading = AppText(
        title,
        style: AppTypography.sectionTitle.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      );
      final button = action == null
          ? null
          : TextButton(
              onPressed: action,
              child: AppText(
                _portfolioCopy('portfolio.view_details', 'View Details'),
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
      color: _categoryColor(activity['category']),
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

class _AllocationPainter extends CustomPainter {
  const _AllocationPainter(this.values, this.colors);
  final List<double> values;
  final List<Color> colors;
  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<double>(0, (a, b) => a + b);
    if (total <= 0) return;
    var start = -math.pi / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18;
    for (var i = 0; i < values.length; i++) {
      final sweep = values[i] / total * math.pi * 2;
      paint.color = colors[i % colors.length];
      canvas.drawArc(
        (Offset.zero & size).deflate(12),
        start,
        sweep,
        false,
        paint,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _AllocationPainter old) =>
      !listEquals(old.values, values) || !listEquals(old.colors, colors);
}

class _ValueHistoryPainter extends CustomPainter {
  const _ValueHistoryPainter(this.values);
  final List<double> values;
  Color get color => values.last < values.first
      ? const Color(0xFFFFB4B4)
      : AppColors.chartGain;
  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final low = values.reduce(math.min), high = values.reduce(math.max);
    final spread = math.max(high - low, 1);
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = i / (values.length - 1) * size.width;
      final y =
          size.height - 5 - (values[i] - low) / spread * (size.height - 10);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _ValueHistoryPainter old) =>
      !listEquals(old.values, values);
}
