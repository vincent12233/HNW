import '../l10n/app_language.dart';
import 'package:flutter/material.dart';

import '../app_config.dart';

class IndexCard extends StatelessWidget {
  const IndexCard({
    super.key,
    required this.name,
    required this.value,
    required this.change,
    required this.positive,
  });

  final String name;
  final String value;
  final String change;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    final color = positive ? AppConfig.gainColor : AppConfig.lossColor;

    return Container(
      padding: const EdgeInsets.all(18),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(18),

        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,

            children: [
              AppText(
                name,
                style: const TextStyle(
                  fontSize: 15,
                  color: Colors.black54,
                  fontWeight: FontWeight.w600,
                ),
              ),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),

                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),

                  borderRadius: BorderRadius.circular(20),
                ),

                child: AppText(
                  'NSE',

                  style: TextStyle(
                    color: color,

                    fontSize: 11,

                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          AppText(
            value,

            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 8),

          Row(
            children: [
              Icon(
                positive ? Icons.arrow_upward : Icons.arrow_downward,

                size: 18,

                color: color,
              ),

              const SizedBox(width: 4),

              AppText(
                change,

                style: TextStyle(
                  color: color,

                  fontSize: 16,

                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          const AppText(
            'Market Overview',

            style: TextStyle(color: Colors.black45, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
