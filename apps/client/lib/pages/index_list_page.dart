import 'package:flutter/material.dart';

import '../l10n/app_language.dart';
import '../theme/app_motion.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_page_scaffold.dart';
import '../widgets/market_status_card.dart';
import '../widgets/markets/market_index_ref.dart';
import '../widgets/markets/markets_index_card.dart';
import 'index_detail_page.dart';

class IndexListPage extends StatelessWidget {
  const IndexListPage({
    super.key,
    required this.title,
    required this.items,
    this.marketOpen,
    this.marketHours = '09:15 - 15:30 IST',
    this.quotesConnected,
    this.onRefresh,
  });

  final String title;
  final List<MarketIndexQuote> items;
  final bool? marketOpen;
  final String marketHours;
  final bool? quotesConnected;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      appBar: AppBar(title: AppText(title)),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: RefreshIndicator(
            onRefresh: onRefresh ?? () async {},
            child: items.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: AppSpacing.page,
                    children: [
                      MarketStatusCard(
                        isOpen: marketOpen,
                        hours: marketHours,
                        quotesConnected: quotesConnected,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      const AppEmptyState(
                        title: 'Index quotes unavailable',
                        message:
                            'Index levels will appear when the market catalog provides them.',
                        icon: Icons.show_chart_rounded,
                      ),
                    ],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: AppSpacing.page,
                    itemCount: items.length + 1,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.md),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return MarketStatusCard(
                          isOpen: marketOpen,
                          hours: marketHours,
                          quotesConnected: quotesConnected,
                        );
                      }
                      final item = items[index - 1];
                      return AppFadeIn(
                        switchKey: item.ref.label,
                        child: MarketsIndexCard(
                          label: item.ref.label,
                          price: item.price,
                          changePercent: item.changePercent,
                          venue: item.ref.venue,
                          history: item.history,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => IndexDetailPage(
                                quote: item,
                                marketOpen: marketOpen,
                                marketHours: marketHours,
                                quotesConnected: quotesConnected,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }
}
