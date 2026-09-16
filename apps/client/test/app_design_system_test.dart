import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:india_trading_app/app_config.dart';
import 'package:india_trading_app/theme/app_colors.dart';
import 'package:india_trading_app/theme/app_radius.dart';
import 'package:india_trading_app/theme/app_spacing.dart';
import 'package:india_trading_app/theme/app_theme.dart';
import 'package:india_trading_app/theme/app_typography.dart';
import 'package:india_trading_app/widgets/app_card.dart';
import 'package:india_trading_app/widgets/app_chip.dart';

void main() {
  test('AppConfig colors delegate to AppColors tokens', () {
    expect(AppConfig.primaryColor, AppColors.brandPrimary);
    expect(AppConfig.gainColor, AppColors.gain);
    expect(AppConfig.lossColor, AppColors.loss);
    expect(AppConfig.backgroundColor, AppColors.background);
  });

  test('light theme uses brand primary and readable on-primary', () {
    final theme = AppTheme.light();
    expect(theme.colorScheme.primary, AppColors.brandPrimary);
    expect(theme.scaffoldBackgroundColor, AppColors.background);
    expect(theme.textTheme.bodyMedium?.fontSize, 14);
  });

  test('high contrast theme preserves accessibility mode', () {
    final theme = AppTheme.highContrast();
    expect(theme.colorScheme.primary, AppColors.hcPrimary);
    expect(theme.textTheme.bodyMedium?.color, AppColors.hcOnSurface);
  });

  test('typography numeric styles use tabular figures', () {
    expect(AppTypography.numericLarge.fontFeatures, isNotEmpty);
    expect(AppTypography.numericLarge.fontFeatures!.first.feature, 'tnum');
  });

  testWidgets('AppCard renders bordered surface', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: AppCard(child: Text('Card'))),
      ),
    );
    expect(find.text('Card'), findsOneWidget);
    expect(find.byType(AppCard), findsOneWidget);
  });

  testWidgets('AppStatusChip renders semantic label', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppStatusChip(
            label: 'Pending',
            variant: AppChipVariant.pending,
          ),
        ),
      ),
    );
    expect(find.text('Pending'), findsOneWidget);
  });

  test('spacing and radius scales are monotonic', () {
    expect(AppSpacing.xs, lessThan(AppSpacing.sm));
    expect(AppSpacing.sm, lessThan(AppSpacing.lg));
    expect(AppRadius.sm, lessThan(AppRadius.md));
    expect(AppRadius.md, lessThan(AppRadius.lg));
  });
}
