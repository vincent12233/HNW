import '../l10n/app_language.dart';
import 'package:flutter/material.dart';

import '../models/market_news_item.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app_card.dart';
import '../widgets/app_page_scaffold.dart';

class MarketNewsPage extends StatefulWidget {
  const MarketNewsPage({
    super.key,
    required this.items,
    required this.onOpen,
    this.onRefresh,
  });

  final List<MarketNewsItem> items;
  final Future<void> Function(MarketNewsItem item) onOpen;
  final Future<List<MarketNewsItem>> Function()? onRefresh;

  @override
  State<MarketNewsPage> createState() => _MarketNewsPageState();
}

class _MarketNewsPageState extends State<MarketNewsPage> {
  late List<MarketNewsItem> items = List.of(widget.items);
  bool refreshing = false;
  bool refreshFailed = false;

  Future<void> refresh() async {
    if (refreshing || widget.onRefresh == null) return;
    setState(() {
      refreshing = true;
      refreshFailed = false;
    });
    try {
      final latest = await widget.onRefresh!();
      if (!mounted) return;
      setState(() {
        if (latest.isNotEmpty) {
          items = latest;
        } else {
          refreshFailed = true;
        }
      });
    } catch (_) {
      if (mounted) setState(() => refreshFailed = true);
    } finally {
      if (mounted) setState(() => refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      title: const AppText('Market News'),
      actions: [
        if (widget.onRefresh != null)
          IconButton(
            tooltip: 'Refresh',
            onPressed: refreshing ? null : refresh,
            icon: const Icon(Icons.refresh),
          ),
      ],
    ),
    body: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: Column(
          children: [
            if (refreshing) const LinearProgressIndicator(minHeight: 2),
            if (refreshFailed)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: AppText(
                  'News could not be updated. Please try again.',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.warning,
                  ),
                ),
              ),
            Expanded(
              child: AppFadeIn(
                switchKey: '${items.length}:$refreshFailed',
                child: RefreshIndicator(
                  onRefresh: refresh,
                  child: items.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: AppSpacing.page,
                          children: [
                            const SizedBox(height: AppSpacing.xxxl),
                            AppEmptyState(
                              title: 'Market news is unavailable',
                              message:
                                  'Headlines will appear when the market news feed is available.',
                              icon: Icons.newspaper_outlined,
                              onRetry: widget.onRefresh == null
                                  ? null
                                  : refresh,
                            ),
                          ],
                        )
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: AppSpacing.page,
                          itemCount: items.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: AppSpacing.sm),
                          itemBuilder: (context, index) {
                            final item = items[index];
                            return AppCard(
                              radius: AppRadius.sm,
                              padding: EdgeInsets.zero,
                              onTap: () => widget.onOpen(item),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 104,
                                    height: 104,
                                    child: item.imageUrl?.isNotEmpty == true
                                        ? Image.network(
                                            item.imageUrl!,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, _, _) =>
                                                _fallbackImage,
                                          )
                                        : _fallbackImage,
                                  ),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.all(
                                        AppSpacing.md,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          AppText(
                                            item.title,
                                            maxLines: 3,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppTypography.titleSmall
                                                .copyWith(
                                                  fontWeight: FontWeight.w800,
                                                  height: 1.3,
                                                ),
                                          ),
                                          const SizedBox(height: AppSpacing.sm),
                                          AppText(
                                            '${item.source} · ${_age(item.publishedAt)}',
                                            style: AppTypography.caption
                                                .copyWith(
                                                  color:
                                                      AppColors.textSecondary,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  static const Widget _fallbackImage = ColoredBox(
    color: AppColors.brandPrimarySoft,
    child: Center(
      child: Icon(
        Icons.candlestick_chart_rounded,
        color: AppColors.brandPrimary,
      ),
    ),
  );

  static String _age(DateTime publishedAt) {
    final difference = DateTime.now().difference(publishedAt);
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    return '${difference.inDays}d ago';
  }
}
