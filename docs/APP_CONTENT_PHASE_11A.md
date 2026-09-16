# App Content Phase 11A

**Commit series:** API harden → Admin align → Flutter About version semantics  
**Baseline before phase:** `d0e4e22`  
**No Prisma / structured-entity work.**

## RBAC

| Item | Result |
|------|--------|
| Effective platform admin role | **`UserRole.ADMIN`** (Admin UI: 超级管理员). No `SUPER_ADMIN` / `PLATFORM_ADMIN` enum. |
| Public `GET /app-content` | Unauthenticated read-only |
| Admin list/write/delete | JWT + `@Roles(ADMIN)` only |
| Desk config `GET /support/desk-content` | JWT + `@Roles(ADMIN, SUPPORT)` — tags / quick replies only |

BUSINESS / FINANCE / SUPPORT do **not** get full CMS write access.

## Audit

| Operation | Audited | Before/after |
|-----------|---------|--------------|
| PUT upsert | Yes (`APP_CONTENT_CREATE` / `APP_CONTENT_UPDATE`) | Yes in `metadata` |
| POST bulk | Yes — **per entry** via upsert | Yes |
| DELETE | Yes (`APP_CONTENT_DELETE`) | before + `after: null` |

Uses existing `AuditLog` / `AuditService` (`metadata` JSON). **No AuditLog schema change.**

Metadata includes: `operatorRole`, `module`, `key`, `locale`, `before`, `after`.

## Public API

| Topic | Before | After |
|-------|--------|-------|
| Locale fallback | requested → en → **any** (could pick zh) | requested → **en only**; omit key if neither |
| Admin-only SUPPORT keys | Returned in public bundle | **Filtered** from public GET |
| SUPPORT zh quick replies public? | **YES** (via locale=zh or any-fallback) | **NO** — use `/support/desk-content` |

## KV

### Added missing keys (defaults + Admin)

| Module | Key |
|--------|-----|
| HOME | `funds.trade_cta_label`, `funds.trade_cta_subtitle` |
| HOME | `profile.section.account`, `profile.section.funds`, `profile.section.legal` |
| TRADING | `shortcut.overview`, `portfolio.page_subtitle` |

### Stable legacy keys retained

| Key | Admin label / default body |
|-----|----------------------------|
| `trading.tab.holdings` | Positions |
| `trading.tab.all` | Overview |
| `home.profile.metric.portfolio` | Product Holdings |

### Deprecated / stale (DB rows **not** deleted)

| Key | Handling |
|-----|----------|
| `home.funds.available_label` | Legacy section in Admin; still seeded / public |
| `trading.portfolio.value_label` | Legacy section in Admin; still seeded / public |

## Admin

- Field definitions extracted to `apps/admin/app/app-content/fields.ts`
- Labels updated for Positions / Overview / Product Holdings / Profile sections
- Trading warning Alert: copy ≠ trading rules
- IPO confirm template labeled as display-only placeholders `{current}`/`{max}`
- Legal info Alert: document type + save responsibility + audit note
- About `app_version` labeled as marketing version
- **saveModule no longer sends `isActive: true`** — body edits preserve `isActive` and omit `sortOrder` so sort order is preserved
- Support console loads `/support/desk-content` instead of public `/app-content?locale=zh`

## Flutter

- About sheet shows **`AppConfig.appVersion`** (`1.0.5`, aligned with pubspec) as the real build label
- CMS `about.app_version` shown only as optional supplementary marketing copy when distinct

## Locale / defaults

- New keys seeded for **en** and **hi** (hi uses existing l10n-aligned short strings / English product names where appropriate)
- Hindi gaps for LEGAL/ABOUT remain en-only (unchanged)

## Tests

- API: `npm test -- --testPathPatterns=app-content` (16 passed)
- API: `tsc -p tsconfig.build.json --noEmit`
- Admin: `eslint`, `tsc --noEmit`, `next build` with `NEXT_PUBLIC_API_URL=https://…`
- Flutter: `flutter analyze` (touched files), `flutter test test/app_content_service_test.dart`

## Safety

- Prisma changed? **NO**
- Migration created? **NO**
- Trading / KYC / funds / market provider logic? **NO**
- Fake financial data? **NO**
- DB KV rows deleted? **NO**
