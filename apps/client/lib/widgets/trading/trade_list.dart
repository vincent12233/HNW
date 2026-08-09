import 'package:flutter/material.dart';

import '../../app_config.dart';
import '../../models/stock_quote.dart';

class TradeList extends StatelessWidget {
  const TradeList({super.key, required this.stocks, required this.onTrade});

  final List<StockQuote> stocks;
  final ValueChanged<StockQuote> onTrade;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 18),
      children: [
        _OverviewCard(
          icon: Icons.swap_horiz_rounded,
          title: 'Trades',
          tag: 'TRD',
          description: 'Trading overview and live execution entries',
          color: AppConfig.primaryColor,
        ),
        _OverviewCard(
          icon: Icons.campaign_outlined,
          title: 'IPO',
          tag: 'IPO',
          description: 'Apply first, then wait for business allocation',
          color: const Color(0xFFEF4444),
        ),
        _OverviewCard(
          icon: Icons.handshake_outlined,
          title: 'OTC',
          tag: 'OTC',
          description: 'Over-the-counter opportunities will appear here',
          color: const Color(0xFF0D9488),
        ),
        _OverviewCard(
          icon: Icons.account_balance_outlined,
          title: 'Institutional Stocks',
          tag: 'INST',
          description: 'New institutional stock offers from the backend',
          color: const Color(0xFF2563EB),
        ),
        _OverviewCard(
          icon: Icons.history_rounded,
          title: 'History',
          tag: 'HIS',
          description: 'Sold holdings, orders and completed records',
          color: const Color(0xFFF59E0B),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({
    required this.icon,
    required this.title,
    required this.tag,
    required this.description,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String tag;
  final String description;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8EDF5)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        tag,
                        style: TextStyle(
                          color: color,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 13,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
        ],
      ),
    );
  }
}
