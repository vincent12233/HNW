import 'package:flutter/material.dart';
import '../l10n/app_language.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Keeps nested routes readable without changing their scrolling or form state.
class AppPageScaffold extends StatelessWidget {
  const AppPageScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.backgroundColor,
    this.bottomNavigationBar,
    this.maxWidth = 760,
  });
  final PreferredSizeWidget? appBar;
  final Widget body;
  final Color? backgroundColor;
  final Widget? bottomNavigationBar;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: appBar,
    backgroundColor: backgroundColor ?? Theme.of(context).colorScheme.surface,
    body: SafeArea(
      top: appBar == null,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: SizedBox(width: double.infinity, child: body),
        ),
      ),
    ),
    bottomNavigationBar: bottomNavigationBar == null
        ? null
        : Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: SafeArea(
              top: false,
              child: Align(
                heightFactor: 1,
                alignment: Alignment.bottomCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: bottomNavigationBar,
                ),
              ),
            ),
          ),
  );
}

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.inbox_outlined,
    this.onRetry,
    this.compact = false,
  });
  final String title;
  final String? message;
  final IconData icon;
  final VoidCallback? onRetry;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final column = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.brandPrimarySoft,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 34, color: AppColors.brandPrimary),
          ),
          const SizedBox(height: AppSpacing.xl - 2),
          AppText(
            title,
            textAlign: TextAlign.center,
            style: AppTypography.titleLarge.copyWith(
              fontWeight: FontWeight.w800,
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
      child: SingleChildScrollView(padding: AppSpacing.page, child: column),
    );
  }
}
