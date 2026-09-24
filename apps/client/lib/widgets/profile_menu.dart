import 'package:flutter/material.dart';

import '../l10n/app_language.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_card.dart';

/// Profile section title + card shell.
class ProfileSection extends StatelessWidget {
  const ProfileSection({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(title, style: AppTypography.titleSmall),
        const SizedBox(height: AppSpacing.sm + 2),
        AppCard(
          padding: EdgeInsets.zero,
          radius: AppRadius.sm,
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const Divider(height: 1, indent: 56),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Standard Profile navigation row.
class ProfileMenuRow extends StatelessWidget {
  const ProfileMenuRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle = '',
    this.status,
    this.statusColor = AppColors.textSecondary,
    this.onTap,
    this.color = AppColors.brandDark,
    this.destructive = false,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? status;
  final Color statusColor;
  final VoidCallback? onTap;
  final Color color;
  final bool destructive;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final accent = destructive ? AppColors.loss : color;
    return ListTile(
      minTileHeight: 52,
      visualDensity: VisualDensity.compact,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: 0,
      ),
      leading: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.10),
          borderRadius: AppRadius.borderSm,
        ),
        child: Icon(icon, color: accent, size: 18),
      ),
      title: AppText(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.labelLarge.copyWith(
          fontWeight: FontWeight.w700,
          color: destructive ? AppColors.loss : AppColors.textPrimary,
        ),
      ),
      subtitle: subtitle.isEmpty
          ? null
          : AppText(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
      trailing:
          trailing ??
          (status == null && (onTap == null || destructive)
              ? null
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (status != null)
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 86),
                        child: AppText(
                          status!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    if (onTap != null && !destructive)
                      const Icon(
                        Icons.chevron_right,
                        size: 20,
                        color: AppColors.textTertiary,
                      ),
                  ],
                )),
      onTap: onTap,
    );
  }
}
