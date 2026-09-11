import 'package:flutter/material.dart';

import '../app_config.dart';
import '../l10n/app_language.dart';

/// A centered, width-constrained empty state that remains balanced on phones,
/// tablets and large accessibility text sizes.
class ResponsiveEmptyState extends StatelessWidget {
  const ResponsiveEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.iconColor,
    this.action,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color? iconColor;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = iconColor ?? theme.colorScheme.primary;
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontal = constraints.maxWidth < 380 ? 24.0 : 32.0;
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: horizontal, vertical: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: (constraints.maxHeight - 48).clamp(180.0, 420.0),
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 390),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.10),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, size: 38, color: color),
                    ),
                    const SizedBox(height: 20),
                    AppText(
                      title,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppConfig.textPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 10),
                    AppText(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppConfig.textSecondaryColor,
                        height: 1.45,
                      ),
                    ),
                    if (action != null) ...[
                      const SizedBox(height: 20),
                      action!,
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
