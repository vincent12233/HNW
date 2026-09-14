import 'package:flutter/material.dart';
import '../app_config.dart';
import '../l10n/app_language.dart';

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
  });
  final String title;
  final String? message;
  final IconData icon;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppConfig.primaryColor.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 34, color: AppConfig.primaryColor),
              ),
              const SizedBox(height: 18),
              AppText(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (message != null) ...[
                const SizedBox(height: 10),
                AppText(
                  message!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppConfig.textSecondaryColor,
                    height: 1.45,
                  ),
                ),
              ],
              if (onRetry != null) ...[
                const SizedBox(height: 18),
                OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const AppText('Retry'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
