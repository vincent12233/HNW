import 'package:flutter/material.dart';

import '../models/market_news_item.dart';

class MarketNewsPage extends StatelessWidget {
  const MarketNewsPage({
    super.key,
    required this.items,
    required this.onOpen,
  });

  final List<MarketNewsItem> items;
  final Future<void> Function(MarketNewsItem item) onOpen;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Market News')),
    body: items.isEmpty
        ? const Center(child: Text('Market news is unavailable'))
        : ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = items[index];
              return Card(
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => onOpen(item),
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
                                errorBuilder: (_, _, _) => _fallbackImage,
                              )
                            : _fallbackImage,
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  height: 1.3,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
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
