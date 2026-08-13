import 'dart:typed_data';

import 'package:flutter/material.dart';

class MarketHeader extends StatelessWidget {
  const MarketHeader({
    super.key,
    required this.accountName,
    required this.onNotificationTap,
    required this.onSearchTap,
    this.notificationCount = 0,
    this.avatarBytes,
    this.onAvatarTap,
  });

  final String accountName;
  final VoidCallback onNotificationTap;
  final VoidCallback onSearchTap;
  final int notificationCount;
  final Uint8List? avatarBytes;
  final VoidCallback? onAvatarTap;

  String get greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 18) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            InkWell(
              onTap: onAvatarTap,
              customBorder: const CircleBorder(),
              child: CircleAvatar(
                radius: 27,
                backgroundColor: const Color(0xFFE7F0FF),
                backgroundImage: avatarBytes == null
                    ? null
                    : MemoryImage(avatarBytes!),
                child: avatarBytes != null
                    ? null
                    : Text(
                        accountName.trim().isEmpty
                            ? 'C'
                            : accountName.trim()[0].toUpperCase(),
                        style: const TextStyle(
                          color: Color(0xFF1769FF),
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        greeting,
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 5),
                      const Icon(
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
            IconButton(
              tooltip: 'Search',
              onPressed: onSearchTap,
              icon: const Icon(Icons.search_rounded, size: 28),
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
