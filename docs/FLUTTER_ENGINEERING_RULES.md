# Flutter Engineering Rules

Last updated: 2026-09-28

This document turns the mobile architecture rules into reviewable engineering
contracts. The authoritative short form is the repository `AGENTS.md`.

## Design system

Feature code consumes semantic tokens rather than literal visual values. Raw
colors are allowed only in token definitions, painters/charts that model data,
and legally fixed marks. `Colors.transparent` is not a brand color.

Typography uses the Material `TextTheme` or `AppTypography`. Local `copyWith`
may change weight, color, overflow, and emphasis; new arbitrary size scales must
be added centrally and tested.

## Responsive layout

Use the available parent constraints. Shared breakpoints live in
`theme/app_breakpoints.dart`; `AppResponsive` exposes the derived window class
and accessibility-relevant state. ScreenUtil is intentionally not required:
proportional scaling is not a replacement for constrained layout.

Required regression dimensions are 320x640, 360x800, 390x844, 430x932,
600x960, 768x1024, and a representative landscape viewport. Critical forms
must also be exercised with keyboard insets and text scales 1.0, 1.3, and 1.4.

## Localization ownership

Stable interface copy belongs to the local localization catalogue. Operational,
legal, promotional, announcement, and support copy may be supplied by CMS with
an English local fallback. API failures should expose stable error codes; the
client maps those codes to localized presentation copy.

The existing `tr`/`AppText` API remains the compatibility boundary while the
large catalogue is decomposed. New feature code must not bypass it. Migration
must be incremental and test-backed so seven supported locales and CMS override
behavior remain intact.

## Credentials and configuration

Only `SecureCredentialStore` may instantiate FlutterSecureStorage. Theme and
locale are safe in SharedPreferences. Sessions, biometric tokens, recovery
tokens, OTPs, passwords, and recovery codes are not.

A dart-define value is extractable from a shipped application and therefore is
not a secret. See `CONFIGURATION_CLASSIFICATION.md`.

## Automated enforcement

`node scripts/check-flutter-architecture.mjs` rejects direct secure-storage use
outside the credential boundary and prevents increases in legacy raw visual and
copy debt. The baseline is a migration ceiling, not permission to add more.
Whenever debt is removed, update the baseline downward in the same commit.
