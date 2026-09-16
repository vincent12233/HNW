# HNW App Design System

Phase 3 foundation for the Flutter client (`apps/client`). This document maps directly to code under `lib/theme/` and shared widgets.

## Brand philosophy

HNW is a professional financial investment app. The visual language is:

- **Professional, premium, calm, trustworthy**
- Deep navy + controlled royal blue + neutral slate
- High information density with readable hierarchy
- Surfaces defined by **border + spacing**, not heavy shadows

### Do

- Use semantic tokens from `AppColors`, `AppTypography`, `AppSpacing`, `AppRadius`
- Use shared components: `AppCard`, `AppPrimaryButton`, `AppStatusChip`, `AppLoadingView`
- Keep gain/loss colors consistent for P&L and market movement
- Preserve High Contrast mode via Appearance settings

### Don't

- Add `Color(0xFF...)` in new shared UI code
- Use large capsule nav indicators, neon accents, or glassmorphism
- Replace every page-level hardcoded color in one pass (migrate incrementally)
- Change trading, KYC, or navigation architecture in this phase

---

## Single source of truth

| Layer | File | Role |
|-------|------|------|
| Colors | `lib/theme/app_colors.dart` | Semantic color tokens |
| Typography | `lib/theme/app_typography.dart` | Text scale + tabular numerics |
| Spacing | `lib/theme/app_spacing.dart` | Layout rhythm |
| Radius | `lib/theme/app_radius.dart` | Corner radii |
| Shadows | `lib/theme/app_shadows.dart` | Minimal elevation |
| Surfaces | `lib/theme/app_ui.dart` | Decorations + gain/loss helpers |
| Theme | `lib/theme/app_theme.dart` | Material `ThemeData` |
| Legacy aliases | `lib/app_config.dart` | Backward-compatible color names |

`AppConfig.primaryColor` etc. delegate to `AppColors` — existing imports keep working.

---

## Color tokens

| Token | Hex | Usage |
|-------|-----|-------|
| `brandPrimary` | `#2558D9` | Primary actions, links, selected nav |
| `brandPrimaryPressed` | `#1E49B8` | Pressed primary button |
| `brandPrimarySoft` | `#EAF0FA` | Soft highlights, nav indicator |
| `brandDark` | `#102A56` | Hero gradients, brand chrome |
| `brandGradientEnd` | `#1A4089` | Gradient end |
| `background` | `#F6F8FC` | Scaffold background |
| `surface` | `#FFFFFF` | Cards, sheets, app bar |
| `surfaceSecondary` | `#F1F4F9` | Subtle panels |
| `surfaceElevated` | `#FFFFFF` | Elevated cards (with border/shadow) |
| `surfaceInput` | `#F8FAFC` | Input fill |
| `border` | `#DCE3EE` | Default borders |
| `borderStrong` | `#B8C4D4` | Emphasized borders |
| `divider` | `#E8EDF3` | Dividers |
| `textPrimary` | `#0F172A` | Headings, body |
| `textSecondary` | `#475569` | Secondary copy |
| `textTertiary` | `#64748B` | Hints, chevrons |
| `textInverse` | `#FFFFFF` | Text on primary buttons |
| `textDisabled` | `#94A3B8` | Disabled labels |
| `gain` | `#087F5B` | Positive P&L, buy semantic |
| `gainSoft` | `#ECFDF5` | Gain backgrounds |
| `loss` | `#D92D4B` | Negative P&L, sell semantic |
| `lossSoft` | `#FFF1F2` | Loss backgrounds |
| `warning` | `#D97706` | Warnings, pending |
| `warningSoft` | `#FFFBEB` | Warning backgrounds |
| `info` / `infoSoft` | brand blue / soft | Informational chips |
| `disabled` | `#E2E8F0` | Disabled control fill |
| `scrim` | `#66102A56` | Modal overlay |

**Contrast notes:** White on `brandPrimary` meets WCAG AA for button labels at 13px+. Secondary text `#475569` on white passes AA for body copy.

---

## Typography scale

Font: **Roboto** (bundled). Numeric styles use `FontFeature.tabularFigures()`.

| Style | Size | Weight | Use |
|-------|------|--------|-----|
| `display` | 28 | 800 | Hero amounts |
| `headline` | 22 | 800 | Section headers |
| `titleLarge` | 18 | 700 | Dialog titles |
| `titleMedium` | 16 | 700 | App bar, section titles |
| `titleSmall` | 14 | 700 | Card titles |
| `bodyLarge` | 16 | 400 | Prominent body |
| `bodyMedium` | 14 | 400 | Default body |
| `bodySmall` | 12 | 400 | Hints |
| `labelLarge` | 13 | 600 | Buttons |
| `labelMedium` | 12 | 600 | Chips, tabs |
| `labelSmall` | 11 | 600 | Nav labels, captions |
| `caption` | 11 | 400 | Helper text |
| `numericLarge` | 28 | 800 | Portfolio total |
| `numericMedium` | 18 | 700 | Stock prices |
| `numericSmall` | 14 | 600 | Order amounts |

---

## Spacing

| Token | Value |
|-------|-------|
| `xxs` | 2 |
| `xs` | 4 |
| `sm` | 8 |
| `md` | 12 |
| `lg` | 16 |
| `xl` | 20 |
| `xxl` | 24 |
| `xxxl` | 32 |

Common composites: `pagePadding` 16, `sectionGap` 20, `cardPadding` 16, `buttonHeight` 44, `navHeight` 68.

---

## Radius

| Token | Value | Use |
|-------|-------|-----|
| `sm` | 8 | Chips, small controls |
| `md` | 12 | Cards, buttons, inputs |
| `lg` | 16 | Large cards |
| `xl` | 20 | Dialogs, sheet top |
| `pill` | 999 | Pills (rare) |

---

## Shadow

| Token | Use |
|-------|-----|
| `none` | Default cards (border only) |
| `small` | Subtle elevation |
| `medium` | Dialogs |
| `brandHero` | Brand gradient hero (restrained) |

---

## Components

### Cards — `AppCard`

```dart
AppCard(
  padding: AppSpacing.card,
  onTap: () {},
  child: ...,
)
```

### Buttons — `app_buttons.dart`

- `AppPrimaryButton` — brand filled
- `AppSecondaryButton` — outlined
- `AppTertiaryButton` — text; `destructive: true` for danger
- `AppBuyButton` / `AppSellButton` — trade semantics (visual only)

Theme-level: `FilledButton`, `OutlinedButton`, `TextButton` in `AppTheme.light()`.

### Inputs

Configured via `inputDecorationTheme` in `app_theme.dart`. Onboarding uses `onboardingInput()` with the same tokens.

### Navigation

5-tab bottom nav unchanged. Theme: 68dp height, 22px icons, soft blue indicator (`brandPrimarySoft`), no large capsule.

### Tabs / Segmented controls

`segmentedButtonTheme` — selected fill `brandPrimary`, 8px radius.

### Chips — `AppStatusChip`

Variants: `neutral`, `info`, `success`, `pending`, `failed`, `gain`, `loss`.

### Dialog / Bottom sheet / Snackbar

- Dialog: 20px radius, 8 elevation, title `titleLarge`
- Sheet: 20px top radius, drag handle `borderStrong`
- Snackbar: floating, dark slate background (not full-width green/red)

### Feedback — `app_feedback.dart`

- `AppLoadingView` — centered spinner
- `AppErrorView` — error + optional retry
- `AppEmptyState` / `ResponsiveEmptyState` — empty states (existing, tokenized)

---

## Gain / Loss semantics

- Positive values: `AppColors.gain` / `gainSoft`
- Negative values: `AppColors.loss` / `lossSoft`
- Zero/neutral: `textSecondary` or `neutralSoft`
- Helper: `AppUi.gainLossColor(value)`

Buy/Sell buttons use `AppColors.buy` / `sell` (aliases of gain/loss). **No trading logic changes.**

---

## Accessibility

- **High Contrast** mode in `appearance_settings.dart` (`light` | `highContrast`) — preserved
- `AppTheme.highContrast()` strengthens borders, primary `#003399`, black text
- Text scaling clamped in `main.dart` (0.9–1.4) for dense trading UI

---

## Migration guidance

1. New shared UI → import `app_colors.dart` / `app_typography.dart`, not raw hex
2. Existing pages may keep `AppConfig.*` — they now resolve to tokens
3. Replace page-level `Color(0x...)` only when touching that file
4. Prefer `AppCard` over ad-hoc `Container` + `BoxDecoration` for list cards
5. Phase 4+ will apply tokens to Home / Markets / Trade / Portfolio / Profile screens

---

## Files added (Phase 3)

```
apps/client/lib/theme/app_colors.dart
apps/client/lib/theme/app_typography.dart
apps/client/lib/theme/app_spacing.dart
apps/client/lib/theme/app_radius.dart
apps/client/lib/theme/app_shadows.dart
apps/client/lib/widgets/app_card.dart
apps/client/lib/widgets/app_buttons.dart
apps/client/lib/widgets/app_chip.dart
apps/client/lib/widgets/app_feedback.dart
apps/client/test/app_design_system_test.dart
```

Modified: `app_config.dart`, `app_theme.dart`, `app_ui.dart`, shared widgets (`app_page_scaffold`, `responsive_empty_state`, `onboarding_widgets`, `market_status_card`, `home_action_button`).
