import 'package:flutter/material.dart';

class MarketHeader extends StatelessWidget {
  const MarketHeader({
    super.key,
    required this.accountName,
    required this.onNotificationTap,
    this.notificationCount = 0,
  });

  final String accountName;
  final VoidCallback onNotificationTap;
  final int notificationCount;

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
                  const Row(
                    children: [
                      Text(
                        'Good Morning',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(width: 5),
                      Icon(
                        Icons.waving_hand_rounded,
                        size: 15,
                        color: Color(0xFFF59E0B),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    accountName,
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  tooltip: 'Notifications',
                  onPressed: onNotificationTap,
                  icon: const Icon(
                    Icons.notifications_none_rounded,
                    color: Color(0xFF334155),
                    size: 28,
                  ),
                ),
                if (notificationCount > 0)
                  Positioned(
                    right: 8,
                    top: 7,
                    child: Container(
                      width: 17,
                      height: 17,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        notificationCount > 9
                            ? '9+'
                            : notificationCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
