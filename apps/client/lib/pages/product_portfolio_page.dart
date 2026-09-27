import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../l10n/app_language.dart';
import '../models/async_data_state.dart';
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

part 'product_portfolio_holdings_section.dart';
part 'product_portfolio_summary_section.dart';
part 'product_portfolio_details_section.dart';

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
  void _updateState(VoidCallback update) => setState(update);

  String _portfolioCopy(String key, String fallback) => AppContentService
      .instance
      .current
      .text('trading', key, fallback: fallback);

  AsyncDataState<Map<String, dynamic>> _loadState =
      const AsyncDataState.initial();
  String _period = '1M';
  bool _hidden = false;
  int _request = 0;
  String _productView = 'HOLDINGS';

  Map<String, dynamic>? get _data => _loadState.data;
  String? get _error => _loadState.message;
  bool get _loading => _loadState.isLoading;

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
    final previousState = _loadState;
    final periodChanged = period != null && period != _period;
    setState(() {
      _period = period ?? _period;
      _loadState = AsyncDataState.loading(
        data: periodChanged ? null : previousState.data,
        updatedAt: periodChanged ? null : previousState.updatedAt,
      );
    });
    try {
      final data =
          await (widget.loader ?? ClientAccountService().productPortfolio)(
            _period,
          );
      if (mounted && request == _request) {
        setState(() => _loadState = AsyncDataState.success(data));
      }
    } catch (error) {
      if (mounted && request == _request) {
        final message = clientErrorMessage(error);
        setState(() {
          final previousData = _loadState.data;
          _loadState = previousData == null
              ? AsyncDataState.error(message)
              : AsyncDataState.stale(
                  previousData,
                  updatedAt: _loadState.updatedAt ?? DateTime.now(),
                  message: message,
                );
        });
      }
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
                          if (_loadState.updatedAt case final updatedAt?) ...[
                            const SizedBox(height: AppSpacing.xs),
                            AppText(
                              'Last updated ${formatIstDateTime(updatedAt)}',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
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
