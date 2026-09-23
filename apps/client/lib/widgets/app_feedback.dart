import 'package:flutter/material.dart';

import '../l10n/app_language.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Centered loading indicator with optional message.
class AppLoadingView extends StatelessWidget {
  const AppLoadingView({super.key, this.message, this.compact = false});

  final String? message;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = AppMotion.reduce(context);
    final indicator = reduceMotion
        ? Icon(
            Icons.hourglass_empty_rounded,
            size: 28,
            semanticLabel: tr('Loading'),
          )
        : CircularProgressIndicator(semanticsLabel: tr('Loading'));
    final column = Semantics(
      liveRegion: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          indicator,
          if (message != null) ...[
            const SizedBox(height: AppSpacing.lg),
            AppText(
              message!,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
    if (compact) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: column,
      );
    }
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: AppSpacing.page,
        child: column,
      ),
    );
  }
}

/// Error state with optional retry — no fake financial data.
class AppErrorView extends StatelessWidget {
  const AppErrorView({
    super.key,
    required this.title,
    this.message,
    this.onRetry,
    this.icon = Icons.error_outline_rounded,
    this.compact = false,
  });

  final String title;
  final String? message;
  final VoidCallback? onRetry;
  final IconData icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final column = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!compact)
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.lossSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 34, color: AppColors.loss),
            ),
          if (!compact) const SizedBox(height: AppSpacing.xl - 2),
          Semantics(
            liveRegion: true,
            child: AppText(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.titleLarge.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.sm + 2),
            AppText(
              message!,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
          ],
          if (onRetry != null) ...[
            const SizedBox(height: AppSpacing.xl - 2),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size(120, 48)),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const AppText('Retry'),
            ),
          ],
        ],
      ),
    );
    if (compact) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: column,
      );
    }
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: AppSpacing.page,
        child: column,
      ),
    );
  }
}
