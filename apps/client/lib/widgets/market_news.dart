import '../l10n/app_language.dart';
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
        Row(
          children: [
            const Expanded(
              child: AppText(
                'Market News',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: Color(0xFFE8EDF5)),
          ),
          child: Column(
            children: news.take(2).toList().asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;

              return Column(
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    leading: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0EA5E9), Color(0xFF143D8D)],
                        ),
                      ),
                      child: const Icon(
                        Icons.show_chart_rounded,
                        color: Colors.white,
                      ),
                    ),
                    title: AppText(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: AppText(
                      '${item.source} • ${item.time}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),

                  if (index != 1) const Divider(height: 1),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
