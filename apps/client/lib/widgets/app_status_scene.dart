import 'package:flutter/material.dart';

import '../l10n/app_language.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_card.dart';

class AppStatusAction {
  const AppStatusAction({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;
}

class AppStatusScene extends StatelessWidget {
  const AppStatusScene({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    required this.status,
    required this.nextStep,
    this.freshness,
    this.primaryAction,
    this.secondaryAction,
    this.timeline,
  });

  final IconData icon;
  final String title;
  final String message;
  final String status;
  final String nextStep;
  final String? freshness;
  final AppStatusAction? primaryAction;
  final AppStatusAction? secondaryAction;
  final Widget? timeline;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '$title. Status: $status. $message. Next step: $nextStep',
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: AppCard(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: const BoxDecoration(
                        color: AppColors.brandPrimarySoft,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: AppColors.brandPrimary),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(title, style: AppTypography.titleLarge),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    message,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Chip(label: Text(status)),
                      if (freshness != null)
                        Text(
                          freshness!,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                  if (timeline != null) ...[
                    const SizedBox(height: AppSpacing.lg),
                    timeline!,
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  const AppText('Next step', style: AppTypography.labelLarge),
                  const SizedBox(height: AppSpacing.xs),
                  Text(nextStep, style: AppTypography.bodyMedium),
                  if (primaryAction != null || secondaryAction != null) ...[
                    const SizedBox(height: AppSpacing.xl),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        if (primaryAction != null)
                          FilledButton(
                            onPressed: primaryAction!.onPressed,
                            child: Text(primaryAction!.label),
                          ),
                        if (secondaryAction != null)
                          OutlinedButton(
                            onPressed: secondaryAction!.onPressed,
                            child: Text(secondaryAction!.label),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
