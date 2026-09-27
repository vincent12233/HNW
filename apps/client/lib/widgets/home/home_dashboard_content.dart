part of 'home_dashboard.dart';

class _FeaturedList extends StatelessWidget {
  const _FeaturedList({required this.stocks, required this.onOpen});

  final List<StockQuote> stocks;
  final ValueChanged<StockQuote> onOpen;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: AppRadius.sm,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var index = 0; index < stocks.length && index < 8; index++) ...[
            if (index > 0) const Divider(height: 1, color: AppColors.divider),
            stocks[index].price <= 0
                ? ListTile(
                    title: AppText(stocks[index].symbol),
                    subtitle: AppText(
                      stocks[index].name.isEmpty
                          ? stocks[index].exchange
                          : stocks[index].name,
                    ),
                    trailing: const AppText(
                      'Unavailable',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    onTap: () => onOpen(stocks[index]),
                  )
                : StockListTile(
                    stock: stocks[index],
                    onTap: () => onOpen(stocks[index]),
                  ),
          ],
        ],
      ),
    );
  }
}

class _NewsSection extends StatelessWidget {
  const _NewsSection({
    required this.news,
    required this.onOpen,
    required this.onRetry,
  });

  final List<MarketNewsItem> news;
  final ValueChanged<MarketNewsItem> onOpen;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (news.isEmpty) {
      return AppCard(
        radius: AppRadius.sm,
        child: Row(
          children: [
            const Icon(Icons.newspaper_outlined, color: AppColors.textTertiary),
            const SizedBox(width: AppSpacing.md),
            const Expanded(
              child: AppText(
                'Live market news is temporarily unavailable.',
                style: AppTypography.bodySmall,
              ),
            ),
            IconButton(
              onPressed: onRetry,
              tooltip: tr('Retry news'),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final oneColumn = constraints.maxWidth < 340 || textScale > 1.2;
        final cardHeight = textScale > 1.7
            ? 144.0
            : textScale > 1.2
            ? 120.0
            : 96.0;
        final width = oneColumn
            ? constraints.maxWidth
            : (constraints.maxWidth - AppSpacing.sm - 2) / 2;
        return Wrap(
          spacing: AppSpacing.sm + 2,
          runSpacing: AppSpacing.sm + 2,
          children: news
              .take(2)
              .map(
                (item) => SizedBox(
                  width: width,
                  child: AppCard(
                    radius: AppRadius.sm,
                    padding: EdgeInsets.zero,
                    onTap: () => onOpen(item),
                    child: SizedBox(
                      height: cardHeight,
                      child: Row(
                        children: [
                          _NewsThumbnail(
                            imageUrl: item.imageUrl,
                            width: oneColumn ? 92 : 62,
                            height: cardHeight,
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm + 2,
                                vertical: AppSpacing.xs,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  AppText(
                                    item.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.labelMedium.copyWith(
                                      fontWeight: FontWeight.w800,
                                      height: 1.28,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  AppText(
                                    '${item.source} · ${homeRelativeTime(item.publishedAt)}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.caption.copyWith(
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _NewsThumbnail extends StatelessWidget {
  const _NewsThumbnail({
    required this.imageUrl,
    required this.width,
    required this.height,
  });

  final String? imageUrl;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final fallback = ColoredBox(
      color: AppColors.brandPrimarySoft,
      child: const Center(
        child: Icon(
          Icons.newspaper_outlined,
          color: AppColors.brandPrimary,
          size: 24,
        ),
      ),
    );
    return ClipRRect(
      borderRadius: const BorderRadius.horizontal(
        left: Radius.circular(AppRadius.sm),
      ),
      child: SizedBox(
        width: width,
        height: height,
        child: imageUrl?.isNotEmpty == true
            ? Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallback,
              )
            : fallback,
      ),
    );
  }
}
