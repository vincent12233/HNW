import '../l10n/app_language.dart';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../app_config.dart';

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
                radius: 20,
                backgroundColor: const Color(0xFFEAF3FF),
                backgroundImage: avatarBytes == null
                    ? null
                    : MemoryImage(avatarBytes!),
                child: avatarBytes != null
                    ? null
                    : AppText(
                        accountName.trim().isEmpty
                            ? 'C'
                            : accountName.trim()[0].toUpperCase(),
                        style: const TextStyle(
                          color: AppConfig.primaryColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      AppText(
                        greeting,
                        style: const TextStyle(
                          color: AppConfig.textSecondaryColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 5),
                      const Icon(
                        Icons.waving_hand_rounded,
                        size: 15,
                        color: AppConfig.warningColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  AppText(
                    accountName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppConfig.textPrimaryColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Search',
              onPressed: onSearchTap,
              icon: const Icon(Icons.search_rounded, size: 22),
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
                    size: 22,
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
                        color: AppConfig.lossColor,
                        shape: BoxShape.circle,
                      ),
                      child: AppText(
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
