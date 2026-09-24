import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_radius.dart';
import 'app_shadows.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

class AppTheme {
  static ThemeData highContrast() {
    final base = light();
    return base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.hcPrimary,
        onSurface: AppColors.hcOnSurface,
        outline: AppColors.hcOutline,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.hcOnSurface,
        displayColor: AppColors.hcOnSurface,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.hcDivider,
        thickness: 1.5,
      ),
      cardTheme: base.cardTheme.copyWith(
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.borderSm,
          side: const BorderSide(color: AppColors.hcOutline, width: 1.5),
        ),
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        enabledBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: AppColors.hcOnSurface, width: 1.5),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: AppColors.hcPrimary, width: 2.5),
        ),
      ),
      iconTheme: const IconThemeData(color: AppColors.hcOnSurface),
      navigationBarTheme: base.navigationBarTheme.copyWith(
        indicatorColor: AppColors.hcPrimary.withValues(alpha: 0.12),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            size: 22,
            color: states.contains(WidgetState.selected)
                ? AppColors.hcPrimary
                : AppColors.hcOnSurface,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return AppTypography.labelSmall.copyWith(
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w800
                : FontWeight.w600,
            color: states.contains(WidgetState.selected)
                ? AppColors.hcPrimary
                : AppColors.hcOnSurface,
          );
        }),
      ),
    );
  }

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(seedColor: AppColors.brandPrimary)
        .copyWith(
          primary: AppColors.brandPrimary,
          onPrimary: AppColors.textInverse,
          primaryContainer: AppColors.brandPrimarySoft,
          onPrimaryContainer: AppColors.brandDark,
          secondary: AppColors.textSecondary,
          surface: AppColors.surface,
          onSurface: AppColors.textPrimary,
          error: AppColors.loss,
          onError: AppColors.textInverse,
          outline: AppColors.border,
          surfaceContainerHighest: AppColors.surfaceSecondary,
        );

    return ThemeData(
      useMaterial3: true,
      fontFamily: AppTypography.fontFamily,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      visualDensity: VisualDensity.standard,
      splashFactory: InkSparkle.splashFactory,
      hoverColor: AppColors.brandPrimarySoft.withValues(alpha: 0.45),
      focusColor: AppColors.brandPrimarySoft,
      highlightColor: AppColors.brandPrimarySoft.withValues(alpha: 0.35),
      textTheme: AppTypography.textTheme(),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.brandPrimary,
        selectionColor: AppColors.brandPrimarySoft,
        selectionHandleColor: AppColors.brandPrimary,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thickness: const WidgetStatePropertyAll(4),
        radius: const Radius.circular(AppRadius.pill),
        thumbColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.dragged)
              ? AppColors.borderStrong
              : AppColors.border;
        }),
      ),
      tooltipTheme: const TooltipThemeData(
        waitDuration: Duration(milliseconds: 450),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.xs,
        ),
        minLeadingWidth: 28,
        iconColor: AppColors.brandPrimary,
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        shadowColor: AppColors.brandDark.withValues(alpha: 0.08),
        centerTitle: false,
        toolbarHeight: 56,
        scrolledUnderElevation: 0,
        titleTextStyle: AppTypography.titleMedium,
        surfaceTintColor: Colors.transparent,
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        titleSpacing: AppSpacing.lg,
        actionsPadding: const EdgeInsets.only(right: AppSpacing.xs),
      ),
      cardTheme: CardThemeData(
        elevation: 1,
        shadowColor: AppColors.brandDark.withValues(alpha: 0.08),
        margin: EdgeInsets.zero,
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.borderMd,
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        dividerColor: AppColors.divider,
        indicatorColor: AppColors.brandPrimary,
        indicatorSize: TabBarIndicatorSize.label,
        labelColor: AppColors.textPrimary,
        unselectedLabelColor: AppColors.textTertiary,
        labelStyle: AppTypography.labelLarge.copyWith(
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: AppTypography.labelLarge,
        overlayColor: WidgetStatePropertyAll(
          AppColors.brandPrimarySoft.withValues(alpha: 0.5),
        ),
      ),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return AppColors.disabled;
          return states.contains(WidgetState.selected)
              ? AppColors.brandPrimary
              : AppColors.borderStrong;
        }),
        thumbColor: const WidgetStatePropertyAll(AppColors.surface),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.brandPrimary;
          }
          return AppColors.surface;
        }),
        side: const BorderSide(color: AppColors.borderStrong, width: 1.25),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? AppColors.brandPrimary
              : AppColors.borderStrong;
        }),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 3,
        focusElevation: 3,
        hoverElevation: 4,
        highlightElevation: 2,
        backgroundColor: AppColors.brandPrimary,
        foregroundColor: AppColors.textInverse,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shadowColor: AppColors.brandDark.withValues(alpha: 0.14),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
        textStyle: AppTypography.bodyMedium,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: AppSpacing.navHeight,
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.navIndicator,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: AppRadius.borderMd,
        ),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        labelPadding: const EdgeInsets.only(top: 1),
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) {
            return AppColors.brandPrimarySoft.withValues(alpha: 0.5);
          }
          return null;
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            size: 22,
            color: states.contains(WidgetState.selected)
                ? AppColors.navSelected
                : AppColors.navUnselected,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return AppTypography.labelSmall.copyWith(
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w600,
            color: states.contains(WidgetState.selected)
                ? AppColors.navSelected
                : AppColors.navUnselected,
          );
        }),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style:
            FilledButton.styleFrom(
              minimumSize: Size(0, AppSpacing.buttonHeight),
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.buttonPaddingH,
              ),
              elevation: 0,
              backgroundColor: AppColors.brandPrimary,
              foregroundColor: AppColors.textInverse,
              disabledBackgroundColor: AppColors.disabled,
              disabledForegroundColor: AppColors.textDisabled,
              shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
              textStyle: AppTypography.labelLarge.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textInverse,
              ),
            ).copyWith(
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.disabled)) {
                  return AppColors.disabled;
                }
                if (states.contains(WidgetState.pressed)) {
                  return AppColors.brandPrimaryPressed;
                }
                return AppColors.brandPrimary;
              }),
            ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: Size(0, AppSpacing.buttonHeight),
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.buttonPaddingH),
          elevation: 0,
          backgroundColor: AppColors.brandPrimary,
          foregroundColor: AppColors.textInverse,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
          textStyle: AppTypography.labelLarge.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: Size(0, AppSpacing.buttonHeight),
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl - 2),
          foregroundColor: AppColors.brandPrimary,
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
          textStyle: AppTypography.labelLarge.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.brandPrimary,
          minimumSize: Size(0, AppSpacing.buttonHeightCompact),
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.borderSm),
          textStyle: AppTypography.labelMedium.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: Size.square(AppSpacing.buttonHeight),
          foregroundColor: AppColors.textPrimary,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.borderSm),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return AppColors.textDisabled;
            }
            return states.contains(WidgetState.selected)
                ? AppColors.textInverse
                : AppColors.textPrimary;
          }),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return AppColors.surfaceSecondary;
            }
            return states.contains(WidgetState.selected)
                ? AppColors.brandPrimary
                : AppColors.surface;
          }),
          side: WidgetStateProperty.resolveWith(
            (states) => BorderSide(
              color: states.contains(WidgetState.selected)
                  ? AppColors.brandPrimary
                  : AppColors.border,
            ),
          ),
          textStyle: WidgetStatePropertyAll(
            AppTypography.labelMedium.copyWith(fontWeight: FontWeight.w700),
          ),
          padding: WidgetStatePropertyAll(
            EdgeInsets.symmetric(
              horizontal: AppSpacing.md + 2,
              vertical: AppSpacing.sm + 2,
            ),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: AppRadius.borderSm),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.brandPrimarySoft,
        disabledColor: AppColors.surfaceSecondary,
        checkmarkColor: AppColors.brandPrimary,
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.borderSm),
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.xs + 1,
          vertical: AppSpacing.xxs + 1,
        ),
        labelStyle: AppTypography.labelMedium.copyWith(
          fontWeight: FontWeight.w700,
        ),
        secondaryLabelStyle: AppTypography.labelMedium.copyWith(
          color: AppColors.textInverse,
          fontWeight: FontWeight.w700,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 1,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shadowColor: AppShadows.dialogShadowColor,
        insetPadding: AppSpacing.dialog,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.borderXl),
        titleTextStyle: AppTypography.titleLarge.copyWith(
          fontWeight: FontWeight.w800,
        ),
        contentTextStyle: AppTypography.bodyMedium.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: AppColors.surface,
        showDragHandle: true,
        dragHandleColor: AppColors.borderStrong,
        constraints: const BoxConstraints(maxWidth: 760),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.sheetTop()),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: AppTypography.labelLarge.copyWith(
          color: AppColors.textInverse,
          fontWeight: FontWeight.w600,
        ),
        actionTextColor: AppColors.brandPrimarySoft,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
        elevation: 0,
        insetPadding: const EdgeInsets.all(AppSpacing.md),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.brandPrimary,
        linearTrackColor: AppColors.brandPrimarySoft,
      ),
      inputDecorationTheme: InputDecorationTheme(
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppSpacing.inputPaddingH,
          vertical: AppSpacing.inputPaddingV,
        ),
        hintStyle: AppTypography.bodySmall,
        labelStyle: AppTypography.labelMedium.copyWith(
          color: AppColors.textSecondary,
        ),
        helperStyle: AppTypography.caption,
        errorStyle: AppTypography.caption.copyWith(color: AppColors.loss),
        filled: true,
        fillColor: AppColors.surfaceInput,
        border: OutlineInputBorder(
          borderRadius: AppRadius.borderMd,
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.borderMd,
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.borderMd,
          borderSide: const BorderSide(
            color: AppColors.brandPrimary,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.borderMd,
          borderSide: const BorderSide(color: AppColors.loss),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.borderMd,
          borderSide: const BorderSide(color: AppColors.loss, width: 1.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.borderMd,
          borderSide: BorderSide(color: AppColors.disabled),
        ),
      ),
    );
  }
}
