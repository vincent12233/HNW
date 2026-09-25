import '../l10n/app_language.dart';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

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

  IconData get greetingIcon {
    final hour = DateTime.now().hour;
    if (hour < 6 || hour >= 18) return Icons.nights_stay_outlined;
    if (hour < 12) return Icons.wb_sunny_outlined;
    return Icons.light_mode_outlined;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Semantics(
              label: tr('Profile'),
              button: onAvatarTap != null,
              child: InkWell(
                onTap: onAvatarTap,
                customBorder: const CircleBorder(),
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: ExcludeSemantics(
                    child: CircleAvatar(
                      radius: 19,
                      backgroundColor: AppColors.brandPrimarySoft,
                      backgroundImage: avatarBytes == null
                          ? null
                          : MemoryImage(avatarBytes!),
                      child: avatarBytes != null
                          ? null
                          : AppText(
                              accountName.trim().isEmpty
                                  ? 'C'
                                  : accountName
                                        .trim()
                                        .characters
                                        .first
                                        .toUpperCase(),
                              style: AppTypography.titleMedium.copyWith(
                                color: AppColors.brandPrimary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm + 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(greetingIcon, size: 12, color: AppColors.warning),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: AppText(
                          greeting,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  AppText(
                    accountName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: tr('Search stocks'),
              onPressed: onSearchTap,
              icon: const Icon(
                Icons.search_rounded,
                color: AppColors.textPrimary,
                size: 22,
              ),
            ),
            Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  tooltip: notificationCount > 0
                      ? '${tr('Notifications')} ($notificationCount)'
                      : tr('Notifications'),
                  onPressed: onNotificationTap,
                  icon: const Icon(
                    Icons.notifications_none_rounded,
                    color: AppColors.textPrimary,
                    size: 22,
                  ),
                ),
                if (notificationCount > 0)
                  Positioned(
                    right: 8,
                    top: 7,
                    child: IgnorePointer(
                      child: ExcludeSemantics(
                        child: Container(
                          width: 17,
                          height: 17,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            color: AppColors.loss,
                            shape: BoxShape.circle,
                          ),
                          child: AppText(
                            notificationCount > 9
                                ? '9+'
                                : notificationCount.toString(),
                            textScaler: TextScaler.noScaling,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textInverse,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
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
