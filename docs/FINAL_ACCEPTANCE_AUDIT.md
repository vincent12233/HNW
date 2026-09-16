# Final Acceptance Audit — Pre-Merge / Pre-Production

**Branch:** `cursor/app-ui-ux-admin-upgrade-c5d7`  
**Starting HEAD:** `2324c4e`  
**Ending HEAD:** `f4b9c97`  
**PR:** https://github.com/vincent12233/HNW/pull/84  
**Audit date:** 2026-09-16  

## Status

**BLOCKED**

Not production-ready. Code review of the PR may continue, but **do not merge for production** and **do not claim Production Ready** until blockers below are cleared.

---

## Git

| Item | Result |
|------|--------|
| Branch | `cursor/app-ui-ux-admin-upgrade-c5d7` |
| Working tree at gate | clean @ `2324c4e` |
| Ending HEAD | `f4b9c97` |
| Commits vs `origin/main` (at audit start) | **30** (+ 2 audit commits after) |
| Files changed | **113** |
| Diff size | **+12993 / −3078** |
| Unexpected / forbidden tracked artifacts | **None** (no `.env`, keys, build/, node_modules, dumps) |
| Audit fix commit | `fix: apply dart format for acceptance gate` (format-only) |

### Scope

In-scope: UI/UX, design system, navigation, Home/Markets/Trade presentation/Portfolio/Profile, AppContent CMS, structured content, Admin management, Flutter integration, tests/docs, SaleSmartly support plumbing (early commit on branch).

API touch set is limited to:

- `app-content/*`
- `ops-content/*` (new)
- `market/*` placement + public featured filters
- `app.module.ts` wiring
- Prisma additive migration + schema

**No** matching engine, KYC business, fund ledger, quote ingestion, or instrument-master sync redesign paths in the PR diff.

---

## Security / secrets

| Check | Result |
|-------|--------|
| Secret filenames in PR | PASS |
| Tracked credential files | PASS |
| Diff credential patterns | PASS (`.env.example` placeholders only) |
| Real secrets found | **NO** |

---

## Flutter

| Check | Result |
|-------|--------|
| `dart format --set-exit-if-changed lib test` | **FAIL at `2324c4e`** → fixed in format commit → **PASS** |
| `flutter analyze` | PASS (1 info: curly braces in `market_data_service.dart`) |
| `flutter test` | **149 passed**, **18 skipped**, 0 failed |
| `flutter build apk --debug` | **PASS** (`app-debug.apk`) |
| `flutter build web --dart-define=API_BASE_URL=https://example.invalid` | **PASS** — LOCAL BUILD VALIDATION ONLY |
| Android device / emulator | **NO** (Linux + Chrome only; no AVD) |
| Live Android visual gate | **NOT EXECUTED** → required gate **FAILED** |

---

## Force update gap (PRODUCTION BLOCKER)

| Question | Answer |
|----------|--------|
| A. Dead-end possible? | **YES** — if `forceUpdate=true` and `current < minVersion`, UI blocks the app. With empty `supportUrl`, user only has Retry (useful if admin turns force off). No store install path. |
| B. Is `supportUrl` used as update URL? | **YES** — sole outbound action is “Open support / update link”. |
| C. Safe Play/App Store jump? | **NO** — no `storeUrl`; no hardcoded store links (correctly avoided). |

**Minimal fix proposal (not implemented in this audit):**

1. Add optional `storeUrl` (or platform-specific store URLs) to `AppClientSetting` + Admin UI + public API.  
2. Force-update primary CTA opens store URL when present.  
3. Keep `supportUrl` secondary.  
4. Product policy: refuse to enable `forceUpdate` in Admin without a store URL (confirmation + validation).

Until then: **do not enable forceUpdate in production.**

---

## API

| Check | Result |
|-------|--------|
| lint | PASS (0 errors; prettier warnings in ops-content) |
| full test suite | **327 passed / 79 suites** |
| build (`nest build`) | PASS |

---

## Admin

| Check | Result |
|-------|--------|
| lint | PASS |
| typecheck (`tsc --noEmit`) | PASS |
| build with `NEXT_PUBLIC_API_URL=https://example.invalid` | PASS — LOCAL BUILD VALIDATION ONLY |
| APP Management routes in shell | Present under ADMIN-only menu group |

### RBAC (code review)

- AdminShell APP Management entries exist only on `ADMIN` menu allowlist.
- Ops/market placement controllers use `@Roles(ADMIN)` / `@Roles('ADMIN')`.
- BUSINESS / FINANCE / SUPPORT do not receive APP Management nav keys.
- SUPPORT retains Support Console separately.

Live multi-role browser exercise not run in this environment.

---

## Prisma

| Check | Result |
|-------|--------|
| `prisma validate` | PASS |
| Migration `20260916100000_structured_app_content` | **Additive only** (no DROP/TRUNCATE) |
| Production migrate executed | **NO** |
| Local migrate status | 3 pending migrations including structured content (dev env not fully migrated — expected; do not `reset`/`db push` prod) |

---

## CMS / E2E (code + unit evidence)

| Area | Evidence | Status |
|------|----------|--------|
| Home KV | AppContentService + Admin Content tabs | COMPLETE (logic) |
| Insights publish filter | Public `isPublished: true`; client SUCCESS `[]` ≠ FAILURE | COMPLETE (unit) |
| Insights FAILURE fallback | `listResult` + client tests | COMPLETE (unit) |
| Announcements schedule | Public filters published + starts/ends window; Home max 1 | COMPLETE (unit/code) |
| App Settings safe fail | safeDefaults + gate tests | COMPLETE (unit) |
| Featured Home/Markets | Public filters + client sections hide when empty | COMPLETE (code/unit) |
| Legal | Privacy/Terms; Risk Disclosure deferred | PARTIAL |
| Admin unpublished → not shown | Public queries filter `isPublished` | COMPLETE (API) |
| Live Admin→DB→App loop | Not exercised against running stack in this audit | **GAP** |

### Insights note

Legacy import upsert uses `update: {}`, so **unpublish** of imported rows is preserved. **Hard-delete** of imported rows can be recreated on next public read from legacy seed — follow-up hardening recommended (not changed in this audit).

---

## Trading / KYC / Funds / Market-data safety

| Area | Changed in PR? |
|------|----------------|
| Trading matching / order semantics | **NO** |
| KYC requirements / flow | **NO** |
| Funds / ledger accounting | **NO** |
| Quote provider / ingestion | **NO** |
| Instrument master sync architecture | **NO** (placement flags + public featured filter only) |
| Fake financial data | **NO** |

---

## Known gaps

### Production blockers

1. **Android device/emulator visual acceptance not executed** (required gate).  
2. **Force update lacks store URL** — enabling forceUpdate can create a non-updatable dead-end.

### Follow-ups / reviews

3. Risk Disclosure — **REQUIRES COMPLIANCE REVIEW** (not implemented; do not invent legal conclusion).  
4. Live multi-role Admin RBAC browser pass.  
5. Live CMS Admin→Flutter end-to-end against applied DB.  
6. Apply pending additive migrations in controlled environments (not production from this agent).  
7. Insights hard-delete vs legacy re-import behavior.  
8. API prettier warnings cleanup.  
9. Flutter analyze info (`market_data_service` curly braces).  
10. Gradle/AGP/Kotlin upgrade warnings (future Flutter support).

---

## Recommendation

| Field | Value |
|-------|--------|
| Final status | **BLOCKED** |
| Merge / production | **BLOCKED** — do **not** merge PR #84 for production; do **not** deploy |
| Review | Engineering review of the PR may continue for awareness, but release gate remains blocked |

**Clear blockers by:**

1. Running full Android device/emulator visual checklist and recording evidence.  
2. Shipping a real store update path (`storeUrl` + Admin guard) before any production forceUpdate.  
3. Completing compliance decision on Risk Disclosure.

---

*End of final acceptance audit. No production migration. PR #84 not merged by this agent.*
