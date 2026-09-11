import '../l10n/app_language.dart';
import 'package:flutter/material.dart';

import '../models/market_news_item.dart';

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
    body: Column(
      children: [
        if (refreshing) const LinearProgressIndicator(),
        if (refreshFailed)
          const Padding(
            padding: EdgeInsets.all(12),
            child: AppText(
              'News could not be updated. Please try again.',
              textAlign: TextAlign.center,
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: refresh,
            child: items.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      const SizedBox(height: 80),
                      const Icon(Icons.newspaper_outlined, size: 48),
                      const Center(
                        child: AppText('Market news is unavailable'),
                      ),
                      if (widget.onRefresh != null)
                        Center(
                          child: TextButton(
                            onPressed: refreshing ? null : refresh,
                            child: const AppText('Retry'),
                          ),
                        ),
                    ],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return Card(
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
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
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      AppText(
                                        item.title,
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          height: 1.3,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      AppText(
                                        '${item.source} · ${_age(item.publishedAt)}',
                                        style: const TextStyle(
                                          color: Color(0xFF64748B),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    ),
  );

  static const Widget _fallbackImage = ColoredBox(
    color: Color(0xFFEEF5FF),
    child: Center(
      child: Icon(Icons.candlestick_chart_rounded, color: Color(0xFF0878F9)),
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
