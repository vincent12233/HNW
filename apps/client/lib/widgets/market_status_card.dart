import '../l10n/app_language.dart';
import 'package:flutter/material.dart';

class MarketStatusCard extends StatelessWidget {
  const MarketStatusCard({super.key});

  bool _isMarketOpen() {
    final nowUtc = DateTime.now().toUtc();

    final indiaTime = nowUtc.add(const Duration(hours: 5, minutes: 30));

    final weekday = indiaTime.weekday;

    final isWeekday = weekday >= DateTime.monday && weekday <= DateTime.friday;

    if (!isWeekday) {
      return false;
    }

    final minutes = indiaTime.hour * 60 + indiaTime.minute;

    const marketOpenMinutes = 9 * 60 + 15;

    const marketCloseMinutes = 15 * 60 + 30;

    return minutes >= marketOpenMinutes && minutes <= marketCloseMinutes;
  }

  @override
  Widget build(BuildContext context) {
    final isOpen = _isMarketOpen();

    final statusColor = isOpen ? Colors.green : Colors.red;

    final statusText = isOpen ? 'Market Open' : 'Market Closed';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFF244A9B), Color(0xFF3768C9)],
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.circle, size: 12, color: statusColor),
          const SizedBox(width: 10),
          Expanded(
            child: AppText(
              statusText,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          const AppText(
            '09:15 - 15:30 IST',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
