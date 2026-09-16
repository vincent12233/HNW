import 'package:flutter/material.dart';

/// Single source of truth for HNW app semantic colors.
///
/// Prefer these tokens over `Color(0xFF...)` in shared UI code.
/// Legacy [AppConfig] color fields delegate here for backward compatibility.
abstract final class AppColors {
  // Brand
  static const Color brandPrimary = Color(0xFF2558D9);
  static const Color brandPrimaryPressed = Color(0xFF1E49B8);
  static const Color brandPrimarySoft = Color(0xFFEAF0FA);
  static const Color brandDark = Color(0xFF102A56);
  static const Color brandGradientEnd = Color(0xFF1A4089);

  // Surfaces
  static const Color background = Color(0xFFF6F8FC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceSecondary = Color(0xFFF1F4F9);
  static const Color surfaceElevated = Color(0xFFFFFFFF);
  static const Color surfaceInput = Color(0xFFF8FAFC);

  // Borders
  static const Color border = Color(0xFFDCE3EE);
  static const Color borderStrong = Color(0xFFB8C4D4);
  static const Color divider = Color(0xFFE8EDF3);

  // Text
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textTertiary = Color(0xFF64748B);
  static const Color textInverse = Color(0xFFFFFFFF);
  static const Color textDisabled = Color(0xFF94A3B8);

  // Financial semantics
  static const Color gain = Color(0xFF087F5B);
  static const Color gainSoft = Color(0xFFECFDF5);
  static const Color loss = Color(0xFFD92D4B);
  static const Color lossSoft = Color(0xFFFFF1F2);
  static const Color chartGain = Color(0xFF43C987);

  // Status
  static const Color warning = Color(0xFFD97706);
  static const Color warningSoft = Color(0xFFFFFBEB);
  static const Color info = brandPrimary;
  static const Color infoSoft = brandPrimarySoft;
  static const Color success = gain;
  static const Color successSoft = gainSoft;
  static const Color pending = Color(0xFFD97706);
  static const Color pendingSoft = warningSoft;
  static const Color failed = loss;
  static const Color failedSoft = lossSoft;
  static const Color neutral = Color(0xFF64748B);
  static const Color neutralSoft = Color(0xFFF1F5F9);

  // Trade actions (semantic only — no logic change)
  static const Color buy = gain;
  static const Color buySoft = gainSoft;
  static const Color sell = loss;
  static const Color sellSoft = lossSoft;

  // Overlays & disabled
  static const Color disabled = Color(0xFFE2E8F0);
  static const Color scrim = Color(0x66102A56);

  // Navigation
  static const Color navSelected = brandPrimary;
  static const Color navUnselected = textSecondary;
  static const Color navIndicator = brandPrimarySoft;

  // High contrast overrides (used by [AppTheme.highContrast])
  static const Color hcPrimary = Color(0xFF003399);
  static const Color hcOnSurface = Color(0xFF000000);
  static const Color hcOutline = Color(0xDE000000);
  static const Color hcDivider = Color(0x8A000000);
}
