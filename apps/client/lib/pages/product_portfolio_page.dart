import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../app_config.dart';
import '../l10n/app_language.dart';
import '../services/client_account_service.dart';
import '../utils/client_error_message.dart';
import '../utils/number_formatters.dart';

class ProductPortfolioPage extends StatefulWidget {
  const ProductPortfolioPage({
    super.key,
    required this.onExplore,
    required this.onNotifications,
    this.loader,
  });
  final VoidCallback onExplore;
  final VoidCallback onNotifications;
  final Future<Map<String, dynamic>> Function(String period)? loader;
  @override
  State<ProductPortfolioPage> createState() => _ProductPortfolioPageState();
}

class _ProductPortfolioPageState extends State<ProductPortfolioPage> {
  Map<String, dynamic>? _data;
  String? _error;
  String _period = '1M';
  bool _loading = false;
  bool _hidden = false;
  int _request = 0;
  static const _colors = {
    'Institutional': AppConfig.primaryColor,
    'OTC': Color(0xFF0F9D92),
    'IPO': Color(0xFF9333EA),
  };
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load([String? period]) async {
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

  double _number(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
  List<Map<String, dynamic>> _rows(dynamic value) =>
      (value is List ? value : const [])
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
  String _money(dynamic value) => _hidden
      ? '******'
      : value == null
      ? '--'
      : formatPrice(_number(value));
  String _date(dynamic value) {
    final date = DateTime.tryParse('$value')?.toLocal();
    return date == null ? '--' : date.toString().substring(0, 16);
  }

  Color _pnlColor(dynamic value) => _number(value) == 0
      ? AppConfig.textSecondaryColor
      : _number(value) > 0
      ? AppConfig.gainColor
      : AppConfig.lossColor;

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              const Expanded(
                child: AppText(
                  'Portfolio',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                tooltip: tr('Refresh'),
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh),
              ),
              IconButton(
                tooltip: tr('Notifications'),
                onPressed: widget.onNotifications,
                icon: const Icon(Icons.notifications_none),
              ),
            ],
          ),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Column(
                children: [
                  AppText(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _loading ? null : _load,
                    icon: const Icon(Icons.refresh),
                    label: const AppText('Retry'),
                  ),
                ],
              ),
            ),
          if (data != null) ..._content(data),
        ],
      ),
    );
  }

  List<Widget> _content(Map<String, dynamic> data) {
    final categories = _rows(data['categories']);
    final history = data['history'] is Map
        ? Map<String, dynamic>.from(data['history'])
        : <String, dynamic>{};
    final points = _rows(history['points']);
    final empty = _number(data['positionCount']) == 0;
    return [
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppConfig.primaryDarkColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: AppText(
                    'Total Portfolio Value',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
                IconButton(
                  tooltip: tr(_hidden ? 'Show balances' : 'Hide balances'),
                  onPressed: () => setState(() => _hidden = !_hidden),
                  icon: Icon(
                    _hidden
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: Colors.white70,
                    size: 20,
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final period in ['1D', '1W', '1M', '3M', '1Y', 'All'])
                      Padding(
                        padding: const EdgeInsets.only(left: 3),
                        child: ChoiceChip(
                          label: AppText(period),
                          selected: _period == period,
                          onSelected: (_) => _load(period),
                          showCheckmark: false,
                          selectedColor: Colors.white,
                          backgroundColor: Colors.transparent,
                          side: BorderSide.none,
                          visualDensity: VisualDensity.compact,
                          labelStyle: TextStyle(
                            fontSize: 10,
                            color: _period == period
                                ? AppConfig.primaryDarkColor
                                : Colors.white70,
                          ),
                          padding: EdgeInsets.zero,
                          labelPadding: const EdgeInsets.symmetric(
                            horizontal: 5,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            AppText(
              _money(data['currentValue']),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            AppText(
              '${tr('Total Returns')}: ${_money(data['totalPnl'])}',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            if (!empty && !_hidden)
              SizedBox(
                height: 64,
                width: double.infinity,
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : points.length < 2
                    ? const Center(
                        child: AppText(
                          'Insufficient history',
                          style: TextStyle(color: Colors.white70),
                        ),
                      )
                    : CustomPaint(
                        painter: _ValueHistoryPainter(
                          points
                              .map((row) => _number(row['productValue']))
                              .toList(),
                        ),
                      ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 18),
      _heading('Investment Summary'),
      AppText(
        '${tr('As of')} ${_date(data['asOf'])}',
        style: const TextStyle(
          color: AppConfig.textSecondaryColor,
          fontSize: 11,
        ),
      ),
      const SizedBox(height: 12),
      _metrics([
        ('Total Invested', data['invested']),
        ('Current Value', data['currentValue']),
        ('Total Returns', data['totalPnl']),
      ]),
      const Divider(height: 20),
      _heading(
        'Asset Allocation',
        action: empty ? null : () => _showHoldings(categories),
      ),
      if (empty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            children: [
              const Icon(
                Icons.account_balance_outlined,
                size: 42,
                color: Color(0xFF0F9D92),
              ),
              const SizedBox(height: 12),
              const AppText(
                'No investments yet',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const AppText(
                'No Institutional, OTC or IPO holdings yet.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: widget.onExplore,
                icon: const Icon(Icons.arrow_forward),
                label: const AppText('Explore offers'),
              ),
            ],
          ),
        )
      else
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final legend = Column(
                children: categories
                    .map(
                      (category) => InkWell(
                        onTap: () => _showHoldings([category]),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            children: [
                              Icon(
                                Icons.circle,
                                size: 9,
                                color: _colors[category['category']],
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    AppText(
                                      category['category'].toString(),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    AppText(
                                      _money(category['currentValue']),
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                    const SizedBox(height: 4),
                                    if (!_hidden)
                                      LinearProgressIndicator(
                                        value:
                                            (_number(
                                                      category['allocationPercent'],
                                                    ) /
                                                    100)
                                                .clamp(0.0, 1.0),
                                        minHeight: 2,
                                        color: _colors[category['category']],
                                        backgroundColor: const Color(
                                          0xffedf1f6,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              AppText(
                                _hidden
                                    ? '--'
                                    : '${_number(category['allocationPercent']).toStringAsFixed(1)}%',
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.chevron_right, size: 18),
                            ],
                          ),
                        ),
                      ),
                    )
                    .toList(),
              );
              final donut = SizedBox.square(
                dimension: 128,
                child: CustomPaint(
                  painter: _AllocationPainter(
                    categories.map((c) => _number(c['currentValue'])).toList(),
                    _colors.values.toList(),
                  ),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: AppText(
                              _money(data['currentValue']),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          const AppText(
                            '100%',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppConfig.textSecondaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
              if (_hidden || _number(data['currentValue']) <= 0) return legend;
              if (constraints.maxWidth < 320 ||
                  MediaQuery.textScalerOf(context).scale(1) > 1.2) {
                return Column(
                  children: [donut, const SizedBox(height: 10), legend],
                );
              }
              return Row(
                children: [
                  donut,
                  const SizedBox(width: 14),
                  Expanded(child: legend),
                ],
              );
            },
          ),
        ),
      _heading('Asset Details'),
      const SizedBox(height: 8),
      ...categories.map(
        (category) => Container(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xffe9edf3))),
          ),
          child: InkWell(
            onTap: () => _showHoldings([category]),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor:
                            (_colors[category['category']] ?? Colors.grey)
                                .withValues(alpha: .1),
                        child: Icon(
                          category['category'] == 'OTC'
                              ? Icons.verified_user_outlined
                              : category['category'] == 'IPO'
                              ? Icons.rocket_launch_outlined
                              : Icons.account_balance_outlined,
                          color: _colors[category['category']],
                          size: 19,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: AppText(
                          category['category'].toString(),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const Icon(Icons.chevron_right, size: 20),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _metrics([
                    ('Current Value', category['currentValue']),
                    ('Allocation', category['allocationPercent']),
                    ('Invested', category['invested']),
                    ('Total Returns', category['totalPnl']),
                  ]),
                  if (!_hidden && !empty) ...[
                    const SizedBox(height: 10),
                    LinearProgressIndicator(
                      value: (_number(category['allocationPercent']) / 100)
                          .clamp(0.0, 1.0),
                      minHeight: 3,
                      color: _colors[category['category']],
                      backgroundColor: const Color(0xffedf1f6),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 12),
      _heading('Performance', action: () => _showPerformance(data, history)),
      const SizedBox(height: 12),
      _metrics([
        ('Unrealized P&L', data['unrealizedPnl']),
        ('Realized P&L', data['realizedPnl']),
        ('Recorded P&L', _loading ? null : history['productProfitChange']),
      ]),
      const SizedBox(height: 12),
      AppText(
        '${tr('Best Segment')}: ${tr(data['bestSegment']?.toString() ?? '--')}',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 24),
      _heading(
        'Recent Activity',
        action: () => _showActivity(_rows(data['activity'])),
      ),
      if (_rows(data['activity']).isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: AppText('No product activity yet'),
        ),
      ..._rows(data['activity']).take(5).map(_activityTile),
      const SizedBox(height: 24),
    ];
  }

  Widget _heading(String title, {VoidCallback? action}) => Row(
    children: [
      Expanded(
        child: AppText(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      if (action != null)
        TextButton(onPressed: action, child: const AppText('View Details')),
    ],
  );
  Widget _metrics(List<(String, dynamic)> items) => LayoutBuilder(
    builder: (context, constraints) {
      final columns =
          MediaQuery.textScalerOf(context).scale(1) > 1.2 &&
              constraints.maxWidth < 360
          ? 2
          : items.length;
      return Wrap(
        runSpacing: 14,
        children: items
            .map(
              (item) => SizedBox(
                width: constraints.maxWidth / columns,
                child: Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(
                        item.$1,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppConfig.textSecondaryColor,
                        ),
                      ),
                      const SizedBox(height: 5),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: AppText(
                          item.$1 == 'Allocation'
                              ? (_hidden
                                    ? '--'
                                    : '${_number(item.$2).toStringAsFixed(1)}%')
                              : _money(item.$2),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color:
                                item.$1.contains('P&L') ||
                                    item.$1.contains('Returns')
                                ? _pnlColor(item.$2)
                                : AppConfig.textPrimaryColor,
                          ),
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
                  : 'Asset Details',
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final category in categories) ...[
                AppText(
                  category['category'].toString(),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (_rows(category['positions']).isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: AppText('No holdings'),
                  ),
                for (final position in _rows(category['positions']))
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppText(
                            '${position['symbol']} · ${position['exchange']}',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          AppText(position['name'].toString()),
                          const SizedBox(height: 12),
                          AppText(
                            '${tr('Quantity')}: ${position['quantity']} · ${tr('Available')}: ${position['availableQuantity']}',
                          ),
                          const SizedBox(height: 12),
                          _metrics([
                            ('Average price', position['averagePrice']),
                            ('Current Value', position['currentValue']),
                            ('Unrealized P&L', position['unrealizedPnl']),
                          ]),
                          if (position['valuationSource'] == 'COST')
                            const Padding(
                              padding: EdgeInsets.only(top: 10),
                              child: AppText(
                                'Valued at cost. Market quote unavailable.',
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
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
      color: _colors[activity['category']],
    ),
    title: AppText(
      '${activity['symbol']} · ${tr(activity['category']?.toString() ?? '')}',
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
    ),
    subtitle: AppText(
      '${tr(activity['status'].toString())} · ${_date(activity['at'])}',
      style: const TextStyle(fontSize: 11),
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
              const SizedBox(height: 8),
              AppText('${tr('Quantity')}: ${activity['quantity']}'),
              AppText(
                '${tr('Filled / allocated')}: ${activity['filledQuantity']}',
              ),
              AppText('${tr('Amount')}: ${_money(activity['amount'])}'),
              const SizedBox(height: 8),
              AppText(_date(activity['at'])),
              const SizedBox(height: 8),
              SelectableText(activity['reference'].toString()),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const AppText('Close'),
          ),
        ],
      ),
    ),
  );
  void _showActivity(List<Map<String, dynamic>> rows) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => Scaffold(
            appBar: AppBar(title: const AppText('Recent Activity')),
            body: ListView(
              padding: const EdgeInsets.all(20),
              children: rows.isEmpty
                  ? [const AppText('No product activity yet')]
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
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppText(
              'Performance',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            _metrics([
              ('Unrealized P&L', data['unrealizedPnl']),
              ('Realized P&L', data['realizedPnl']),
              ('Recorded P&L', history['productProfitChange']),
            ]),
            const SizedBox(height: 20),
            AppText('${tr('Period')}: $_period'),
            AppText('${tr('Since')}: ${_date(history['productFrom'])}'),
            AppText('${tr('As of')}: ${_date(history['to'])}'),
            const SizedBox(height: 12),
            const AppText(
              'Returns cover recorded observations only. Deposits and ordinary stocks are excluded.',
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
  bool shouldRepaint(covariant _AllocationPainter old) => old.values != values;
}

class _ValueHistoryPainter extends CustomPainter {
  const _ValueHistoryPainter(this.values);
  final List<double> values;
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
        ..color = const Color(0xFF5EEAD4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _ValueHistoryPainter old) =>
      old.values != values;
}
