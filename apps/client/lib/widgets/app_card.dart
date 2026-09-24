import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';

/// Standard surface card for lists, summaries, and form sections.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.borderColor,
    this.radius = AppRadius.md,
    this.bordered = true,
    this.shadow = AppCardShadow.small,
    this.onTap,
    this.clipBehavior = Clip.antiAlias,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final Color? borderColor;
  final double radius;
  final bool bordered;
  final AppCardShadow shadow;
  final VoidCallback? onTap;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      color: backgroundColor ?? AppColors.surface,
      borderRadius: BorderRadius.circular(radius),
      border: bordered
          ? Border.all(color: borderColor ?? AppColors.divider)
          : null,
      boxShadow: switch (shadow) {
        AppCardShadow.none => AppShadows.none,
        AppCardShadow.small => AppShadows.small,
        AppCardShadow.medium => AppShadows.medium,
      },
    );

    final content = Padding(padding: padding ?? AppSpacing.card, child: child);

    final card = Material(
      color: Colors.transparent,
      clipBehavior: clipBehavior,
      borderRadius: BorderRadius.circular(radius),
      child: Ink(
        decoration: decoration,
        child: onTap == null
            ? content
            : InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(radius),
                child: content,
              ),
      ),
    );

    if (margin == null) return card;
    return Padding(padding: margin!, child: card);
  }
}

enum AppCardShadow { none, small, medium }
