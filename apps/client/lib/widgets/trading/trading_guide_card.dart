import '../../l10n/app_language.dart';
import 'package:flutter/material.dart';

class TradingGuideCard extends StatelessWidget {
  const TradingGuideCard({super.key, required this.body, this.title});

  final String? title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null && title!.isNotEmpty) ...[
            AppText(
              title!,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            ),
            const SizedBox(height: 6),
          ],
          AppText(
            body,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 12,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
