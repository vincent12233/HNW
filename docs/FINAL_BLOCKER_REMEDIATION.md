# Final Blocker Remediation — updateUrl + revalidation

**Branch:** `cursor/app-ui-ux-admin-upgrade-c5d7`  
**Starting HEAD (this phase):** `4b03fa5`  
**Ending HEAD (this phase):** `f7319e2`  
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

### Git gate (Android E2E acceptance attempt @ `101fd0b`)

| Check | Result |
|-------|--------|
| Branch | `cursor/app-ui-ux-admin-upgrade-c5d7` |
| HEAD | `101fd0b` (matches expected) |
| Working tree | clean |
| Host | Linux Cloud Agent — **not** `C:\Users\suyan\HNW` |

### Environment check

| Check | Result |
|-------|--------|
| Flutter | 3.47.4 (stable) / Dart 3.13.3 |
| Android SDK | Present (android-36 / build-tools 36.0.0) — licenses accepted |
| `adb` | Present (`platform-tools`); **no devices attached** |
| `flutter devices` | Linux desktop + Chrome only |
| `flutter emulators` | **No AVD sources** / no emulator configured |
| Real Android handset | **Not attached** |
| Windows path `C:\Users\suyan\HNW` | **Not accessible** from this agent |
| Chrome/Web substitute | **Forbidden** — not used |

### Verdict

**Android device E2E NOT EXECUTED — STOPPED at environment gate.**

Per task rules: do **not** pretend Windows/Android E2E completed. Device name / Android version / resolution / screen PASS-FAIL matrix: **N/A — blocked on environment**.

Must be run on the user’s Windows host (`C:\Users\suyan\HNW`) with a physical device (preferred) or configured emulator:

```text
cd C:\Users\suyan\HNW
git status
flutter devices
adb devices
# start local API on LAN IP (not production)
cd apps\client
flutter run -d <android-device-id> --dart-define=API_BASE_URL=http://<WINDOWS-LAN-IP>:3000
```

Inject maintenance / optional / force update via **dev/test injection or safe local config** — do **not** mutate production DB.

Required screens (still outstanding): Login, Register, Forgot Password, Home, Markets, Search, Stock Detail, Trade, Portfolio, Profile, KYC entry, Bank Details, Deposit, Insights, Announcements, bottom nav, back, keyboard, scrolling, maintenance, optional update, force update (valid + missing URL) — at real device resolution (and ~360/~412 logical width if emulator available).

**No code changes** made in this Android E2E attempt.

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
