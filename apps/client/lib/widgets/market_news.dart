import 'package:flutter/material.dart';

class MarketNews extends StatelessWidget {
  const MarketNews({super.key});

  @override
  Widget build(BuildContext context) {
    final news = [
      (
        title: 'NIFTY closes higher led by banking stocks',
        source: 'Economic Times',
        time: '10 min ago',
      ),
      (
        title: 'Reliance announces expansion in energy business',
        source: 'Moneycontrol',
        time: '25 min ago',
      ),
      (
        title: 'Foreign investors continue buying Indian equities',
        source: 'Business Standard',
        time: '40 min ago',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Market News',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 12),

        Card(
          child: Column(
            children: news.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;

              return Column(
                children: [
                  ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.article_outlined),
                    ),
                    title: Text(
                      item.title,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text('${item.source} • ${item.time}'),
                    trailing: const Icon(Icons.chevron_right),
                  ),

                  if (index != news.length - 1) const Divider(height: 1),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
