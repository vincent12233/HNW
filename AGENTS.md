# HNW Repository Engineering Rules

These rules apply to the whole repository. More specific rules may be added in
subdirectories, but may not weaken security or verification requirements.

## Required delivery sequence

Every pushed change must follow this order:

1. Format changed sources.
2. Run static analysis/lint for affected applications.
3. Run affected focused tests, then the full Flutter test suite for Flutter work.
4. Run release/configuration checks when mobile, credentials, permissions, build
   configuration, CI, or deployment code changes.
5. Review `git diff` and verify no secret, generated build output, or unrelated
   change is present.
6. Commit only after local checks pass.
7. Push once.
8. Inspect every remote CI job and do not call the work complete until required
   jobs succeed. If CI fails, reproduce locally before another push.

Never use repeated speculative commits as a substitute for local validation.

## Flutter architecture

- Widgets must not access HTTP clients, secure storage, databases, or platform
  secrets directly. Use a focused service/repository boundary.
- Sensitive credentials are accessed only through
  `SecureCredentialStore`. SharedPreferences is limited to non-sensitive UI
  preferences and non-secret display cache.
- Use `AppTheme`, `AppColors`, `AppTypography`, `AppSpacing`, `AppRadius`, and
  semantic component tokens. Do not introduce a raw brand color or arbitrary
  text size in a feature page.
- Use constraints, `LayoutBuilder`, `MediaQuery`, and `AppResponsive`; do not
  size the whole interface from a single design-canvas width.
- New layouts must remain usable at 320 logical pixels, landscape, keyboard
  visible, and text scale 1.4.
- User-visible static copy must go through the localization layer. CMS is for
  operational/editorial copy; local resources are for controls, validation,
  accessibility labels, and stable business states.
- Client applications may contain public endpoints and public OAuth client IDs,
  but never database credentials, signing secrets, provider secrets, private
  keys, or privileged webhook tokens.
- Keep pages and services focused. Split a file before it breaches the source
  size guard; do not create meaningless wrapper files merely to satisfy size.

## Business and safety constraints

- Preserve the documented India phone, password/invite registration, KYC,
  deposit review, withdrawal, and trading flows unless the task explicitly
  changes product behavior.
- Never log passwords, OTPs, access tokens, recovery codes, full identity
  documents, bank details, or unredacted phone numbers.
- Financial writes require server-side authorization, validation, audit records,
  and idempotency where retry is possible.

## Definition of done

A change is complete only when code, tests, documentation, local verification,
and required remote CI evidence agree with the same commit.
