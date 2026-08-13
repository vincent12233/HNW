class MarketNewsItem {
  const MarketNewsItem({
    required this.id,
    required this.title,
    required this.source,
    required this.url,
    required this.publishedAt,
    this.imageUrl,
  });
  final String id;
  final String title;
  final String source;
  final String url;
  final String? imageUrl;
  final DateTime publishedAt;

  factory MarketNewsItem.fromJson(Map<String, dynamic> json) => MarketNewsItem(
    id: json['id']?.toString() ?? '',
    title: json['title']?.toString() ?? '',
    source: json['source']?.toString() ?? 'Market News',
    url: json['url']?.toString() ?? '',
    imageUrl: json['imageUrl']?.toString(),
    publishedAt:
        DateTime.tryParse(json['publishedAt']?.toString() ?? '')?.toLocal() ??
        DateTime.now(),
  );
}
