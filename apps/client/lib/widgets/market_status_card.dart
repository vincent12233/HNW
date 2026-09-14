import 'package:flutter/material.dart';

import '../app_config.dart';
import '../l10n/app_language.dart';

class MarketStatusCard extends StatelessWidget {
  const MarketStatusCard({super.key});

  bool _isMarketOpen() {
    final nowUtc = DateTime.now().toUtc();
    final indiaTime = nowUtc.add(const Duration(hours: 5, minutes: 30));
    final weekday = indiaTime.weekday;
    final isWeekday = weekday >= DateTime.monday && weekday <= DateTime.friday;
    if (!isWeekday) return false;
    final minutes = indiaTime.hour * 60 + indiaTime.minute;
    const marketOpenMinutes = 9 * 60 + 15;
    const marketCloseMinutes = 15 * 60 + 30;
    return minutes >= marketOpenMinutes && minutes <= marketCloseMinutes;
  }

  @override
  Widget build(BuildContext context) {
    final isOpen = _isMarketOpen();
    final statusColor = isOpen ? AppConfig.gainColor : AppConfig.lossColor;
    final statusText = isOpen ? 'Market Open' : 'Market Closed';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: AppConfig.cardRadius,
        gradient: AppConfig.heroGradient,
        boxShadow: AppConfig.softShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: statusColor.withValues(alpha: 0.45),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: AppText(
              statusText,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 17,
              ),
            ),
          ),
          const AppText(
            '09:15 - 15:30 IST',
            style: TextStyle(color: Color(0xCCDDE8FF), fontSize: 12),
          ),
        ],
      ),
    );
  }
}
