# Final Blocker Remediation — updateUrl + revalidation

**Branch:** `cursor/app-ui-ux-admin-upgrade-c5d7`  
**Starting HEAD (this phase):** `4b03fa5`  
**Ending HEAD (this phase):** `ca35fa5`  
**PR:** https://github.com/vincent12233/HNW/pull/84  
**Date:** 2026-09-16  

## Scope

Only FINAL ACCEPTANCE launch blockers. No new business features. No trading / KYC / funds / quote logic. No merge of `main`. No production deploy.

---

## 1. updateUrl implementation

### Design

| Platform | Field | Notes |
|----------|-------|-------|
| ANDROID / IOS / WEB | `updateUrl String?` | Single optional http(s) destination |
| — | No `storeUrl` / duplicate fields | Minimal additive field only |
| — | `supportUrl` | Remains support-only; **never** used as Update CTA |

### Prisma

- Schema: `AppClientSetting.updateUrl String?`
- Migration: `20260916120000_add_app_client_update_url`
- SQL: `ALTER TABLE "app_client_settings" ADD COLUMN "updateUrl" TEXT;`
- **Additive only** (no DROP / rename / TRUNCATE)
- Production migrate **not** executed by this agent

### API

- DTO: `UpsertAppClientSettingDto.updateUrl` — optional; when set must be http/https (`IsUrl` + `require_protocol`)
- `getPublic` returns `updateUrl`
- Admin upsert persists `updateUrl`
- `safeDefaults.updateUrl = null`
- Unit tests: Android URL, iOS URL, audit with updateUrl, safe defaults

### Admin

- App Settings form + table column for `updateUrl`
- Client-side http(s) validator
- Warning: enable Force Update only with a valid `updateUrl` (client still soft-continues if missing)

### Flutter

- `AppClientSettings.updateUrl` + `parseValidUpdateUrl` / `validUpdateUri`
- Force update page:
  - Valid URL → **Update** opens `updateUrl` externally
  - Missing/invalid → **Continue** via `continueWithoutUpdateDestination()` (session soft path; **no dead-end**)
  - Retry still available
- Optional update dialog uses the same `updateUrl` (Later / Update / OK)
- Does **not** hardcode Play/App Store links
- Does **not** use `supportUrl` as update destination
- API failure still fail-open (`safeDefaults`)

### Commit

`feat: add safe client update destination` (`f97bfbd`)

---

## 2. Android device E2E

### Environment check (this Cloud Agent host)

| Check | Result |
|-------|--------|
| Host OS | Linux (Ubuntu 24.04) — **not** user Windows |
| `flutter devices` | Linux desktop + Chrome only |
| `adb devices` | Empty |
| `flutter emulators` | No AVD sources / no emulator configured |
| Real Android handset | **Not attached** |

### Verdict

**Android device E2E NOT EXECUTED** on this Linux cloud agent.

Per task rules: do **not** pretend Windows/Android E2E completed. Device name / Android version / viewport pass-fail matrix: **N/A — blocked on environment**.

Must be run on the user’s Windows host (`C:\Users\suyan\HNW`) with:

```text
flutter devices
adb devices
flutter run -d <device>
```

Prefer physical device; else configured emulator. Inject maintenance / optional / force update via **dev/test injection or safe local config** — do **not** mutate production DB.

Required screens (still outstanding): Login, Register, Forgot Password, Home, Markets, Search, Stock Detail, Trade, Portfolio, Profile, KYC entry, Bank Details, Deposit, Insights, Announcements, bottom nav, back, keyboard, scrolling, maintenance, optional update, force update — at ~360px and ~412px when available.

---

## 3. Re-run validation (post-updateUrl)

| Gate | Result |
|------|--------|
| `dart format --set-exit-if-changed lib test` | PASS |
| `flutter analyze` | PASS with 1 pre-existing **info** (`market_data_service.dart` curly braces) |
| `flutter test` | **157 passed**, **18 skipped**, 0 failed |
| `flutter build apk --debug` | PASS (`app-debug.apk`) |
| `flutter build web --dart-define=API_BASE_URL=https://example.invalid` | PASS — LOCAL BUILD ONLY |
| API `npm run lint` | PASS (0 errors; existing prettier warnings) |
| API `npm test` | **328 passed** / 79 suites |
| API `npm run build` | PASS |
| Admin `npm run lint` | PASS |
| Admin `tsc --noEmit` | PASS |
| Admin build (`NEXT_PUBLIC_API_URL=https://example.invalid`) | PASS — LOCAL BUILD ONLY |
| `prisma validate` | PASS |
| Migration SQL inspection | Additive `ADD COLUMN "updateUrl"` only |
| Secret scan (filenames + diff patterns) | PASS — no secrets |
| Working tree after docs commit | clean (expected) |

---

## 4. Remaining blockers

1. **Android device / emulator visual E2E** — still required; not runnable here.  
2. Risk Disclosure — keep **REQUIRES_COMPLIANCE_REVIEW** (no invented legal text).  
3. Live Admin→DB→App CMS loop / multi-role RBAC browser (follow-up, not this phase’s sole gate).

### Cleared vs prior acceptance

| Prior blocker | Status after remediation |
|---------------|--------------------------|
| Force update dead-end / no store URL | **RESOLVED in code** — `updateUrl` + Continue soft path |
| Android device E2E | **STILL BLOCKED** |

---

## 5. Final status

**BLOCKED**

Cannot mark `READY_FOR_REVIEW` until Android device E2E PASS is recorded on the Windows host.

PR #84 not merged. No production deploy. No production migration.

---

*End of FINAL_BLOCKER_REMEDIATION.*
