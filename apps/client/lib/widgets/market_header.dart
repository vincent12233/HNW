import '../l10n/app_language.dart';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
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
                backgroundColor: AppColors.brandPrimarySoft,
                backgroundImage: avatarBytes == null
                    ? null
                    : MemoryImage(avatarBytes!),
                child: avatarBytes != null
                    ? null
                    : AppText(
                        accountName.trim().isEmpty
                            ? 'C'
                            : accountName.trim()[0].toUpperCase(),
                        style: AppTypography.titleMedium.copyWith(
                          color: AppColors.brandPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm + 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(
                    greeting,
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
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
            Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  tooltip: 'Notifications',
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
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textInverse,
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
        const SizedBox(height: AppSpacing.md),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onSearchTap,
            borderRadius: AppRadius.borderSm,
            child: Ink(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm + 3,
              ),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppRadius.borderSm,
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.search_rounded,
                    size: 20,
                    color: AppColors.textTertiary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: AppText(
                      'Search stocks, indices…',
                      style: AppTypography.labelLarge.copyWith(
                        color: AppColors.textTertiary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
