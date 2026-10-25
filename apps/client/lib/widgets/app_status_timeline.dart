import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

enum AppStatusStepState { upcoming, current, done }

class AppStatusStep {
  const AppStatusStep({
    required this.label,
    this.description,
    this.state = AppStatusStepState.upcoming,
  });

  final String label;
  final String? description;
  final AppStatusStepState state;
}

class AppStatusTimeline extends StatelessWidget {
  const AppStatusTimeline({super.key, required this.steps});

  final List<AppStatusStep> steps;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < steps.length; index++)
          _TimelineRow(
            step: steps[index],
            showConnector: index < steps.length - 1,
          ),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.step, required this.showConnector});

  final AppStatusStep step;
  final bool showConnector;

  @override
  Widget build(BuildContext context) {
    final active = step.state != AppStatusStepState.upcoming;
    final done = step.state == AppStatusStepState.done;
    return Semantics(
      label: '${step.label}, ${step.state.name}',
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 32,
              child: Column(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: active
                          ? AppColors.brandPrimary
                          : AppColors.surfaceSecondary,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: active
                            ? AppColors.brandPrimary
                            : AppColors.border,
                      ),
                    ),
                    child: done
                        ? const Icon(
                            Icons.check_rounded,
                            size: 16,
                            color: AppColors.textInverse,
                          )
                        : active
                        ? const Icon(
                            Icons.circle,
                            size: 8,
                            color: AppColors.textInverse,
                          )
                        : null,
                  ),
                  if (showConnector)
                    Expanded(
                      child: Container(
                        width: 2,
                        color: done ? AppColors.brandPrimary : AppColors.border,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(step.label, style: AppTypography.labelLarge),
                    if (step.description != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        step.description!,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
