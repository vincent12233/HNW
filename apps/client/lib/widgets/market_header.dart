import 'package:flutter/material.dart';

import '../app_config.dart';

class MarketHeader extends StatelessWidget {
  const MarketHeader({
    super.key,
    required this.accountName,
    required this.onSearchTap,
  });

  final String accountName;
  final VoidCallback onSearchTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Welcome back',
                    style: TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    accountName,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            CircleAvatar(
              backgroundColor: AppConfig.primaryColor,
              child: Text(
                accountName.isNotEmpty
                    ? accountName.substring(0, 1).toUpperCase()
                    : 'U',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onSearchTap,
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: const Row(
              children: [
                Icon(Icons.search, color: Colors.black45),
                SizedBox(width: 10),
                Text(
                  'Search stocks, ETFs, indices...',
                  style: TextStyle(color: Colors.black45),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
