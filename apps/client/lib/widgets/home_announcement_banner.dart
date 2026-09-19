import 'package:flutter/material.dart';

import '../l10n/app_language.dart';
import '../services/announcements_service.dart';
import '../theme/app_colors.dart';

/// Lightweight Home announcement strip — at most one live item.
class HomeAnnouncementBanner extends StatelessWidget {
  const HomeAnnouncementBanner({super.key, required this.item});

  final AnnouncementItem item;

  IconData get _icon {
    switch (item.type.toUpperCase()) {
      case 'MAINTENANCE':
        return Icons.engineering_outlined;
      case 'IMPORTANT':
        return Icons.priority_high;
      case 'MARKET_NOTICE':
        return Icons.campaign_outlined;
      default:
        return Icons.info_outline;
    }
  }

  Color get _accent {
    switch (item.type.toUpperCase()) {
      case 'MAINTENANCE':
        return const Color(0xFFB45309);
      case 'IMPORTANT':
        return const Color(0xFFB91C1C);
      case 'MARKET_NOTICE':
        return const Color(0xFF1D4ED8);
      default:
        return AppColors.brandPrimary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _accent.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          showModalBottomSheet<void>(
            context: context,
            showDragHandle: true,
            builder: (ctx) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(_icon, color: _accent),
                        const SizedBox(width: 8),
                        Expanded(
                          child: AppText(
                            item.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    AppText(item.body, style: const TextStyle(height: 1.5)),
                  ],
                ),
              );
            },
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(_icon, color: _accent, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _accent,
                      ),
                    ),
                    const SizedBox(height: 2),
                    AppText(
                      item.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

AnnouncementItem? pickTopAnnouncement(List<AnnouncementItem> items) {
  if (items.isEmpty) return null;
  final now = DateTime.now();
  final live = items.where((item) {
    if (item.endsAt != null && item.endsAt!.isBefore(now)) return false;
    if (item.startsAt != null && item.startsAt!.isAfter(now)) return false;
    return true;
  }).toList();
  if (live.isEmpty) return null;
  live.sort((a, b) {
    final byPriority = b.priority.compareTo(a.priority);
    if (byPriority != 0) return byPriority;
    return a.sortOrder.compareTo(b.sortOrder);
  });
  return live.first;
}
