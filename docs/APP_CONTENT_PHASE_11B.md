# App Content Phase 11B — Structured App Content Entities

**Status:** Implemented (development migration only; no production migrate).  
**Baseline before phase:** `527ed92`  
**Compatibility choice:** **B** — public Insights API prefers structured `InsightArticle`; legacy `AppContentEntry` INSIGHTS `article.01`–`08` retained as temporary client fallback; Admin KV + structured tools coexist.

---

## Why structured

| Content | Why leave KV |
|---------|----------------|
| Insights | Editorial lifecycle (draft/publish/sort/slug), not a fixed 8-key grid |
| Announcements | Scheduling + type; ≠ Market News ≠ Banner |
| App client settings | Validated version/maintenance gates; not free-form HOME keys |

Banner Home/Markets remains **KEEP_AS_KV** (title/subtitle/CTA only). Featured stocks reuse **Instrument** flags — no second catalog table.

---

## New models / enums

### Prisma

| Model | Notes |
|-------|--------|
| `InsightArticle` | `@@unique([slug, locale])`; draft via `isPublished`; optional `imageUrl` |
| `Announcement` | `AnnouncementType`; `startsAt`/`endsAt`; priority + sortOrder |
| `AppClientSetting` | `@@unique` on `AppClientPlatform` (ANDROID/IOS/WEB) |
| `Instrument.featuredHome` / `featuredMarkets` | Additive booleans + indexes |

### Enums

- `AnnouncementType`: GENERAL | MAINTENANCE | IMPORTANT | MARKET_NOTICE  
- `AppClientPlatform`: ANDROID | IOS | WEB  

### Retained

- `AppContentEntry` **not** dropped  
- Legacy Insights KV keys **not** deleted  
- Migration SQL is **additive only** (`apps/api/prisma/migrations/20260916100000_structured_app_content/`)

---

## Version semantics (`AppClientSetting`)

| Field | Meaning |
|-------|---------|
| `minVersion` | Below this may be blocked if `forceUpdate` |
| `latestVersion` | Soft “new version available” hint |
| `forceUpdate` | Enforce gate when below min |
| `maintenanceMode` / `maintenanceMessage` | Platform maintenance switch |
| `supportUrl` | Optional support link |

Not stored here: API base URL, market provider, secrets, tokens, marketing `about.app_version`.

---

## Public API (no auth)

| Method | Path | Behavior |
|--------|------|----------|
| GET | `/insights?locale=` | Published only; locale → en pick |
| GET | `/insights/:slug?locale=` | Published slug lookup |
| GET | `/announcements?locale=` | Published + in schedule window |
| GET | `/app-settings?platform=` | Per-platform row; safe defaults if missing |

Admin metadata (createdBy/updatedBy) not exposed on public reads.

---

## Admin API (`ADMIN` only + AuditLog)

| Area | Endpoints |
|------|-----------|
| Insights | GET/POST `/admin/insights`, PUT/DELETE `/admin/insights/:id` |
| Announcements | GET/POST `/admin/announcements`, PUT/DELETE `/admin/announcements/:id` |
| Settings | GET `/admin/app-settings`, PUT `/admin/app-settings/:platform` |

Audit actions include create/update/delete (and settings upsert) with `before`/`after` in metadata. Reuses existing `AuditLog`.

---

## Legacy Insights compatibility

1. Idempotent upsert import from seed mapping (`insight-legacy-import.ts`) on Insights service read paths.  
2. Client Learning Center: **structured API → KV `article.*` → local static list**.  
3. Old Admin `/app-content` Insights KV section remains.

---

## Banner decision

**KEEP_AS_KV** — current Home/Markets banners are title/subtitle/CTA only; no image/deepLink/schedule/multi-banner requirement yet.

---

## Featured stocks

- Approach: `Instrument.featuredHome` + `Instrument.featuredMarkets` (+ existing `displayOrder` / `isActive`)  
- CreateInstrument DTO/service persist flags  
- **No** second stock / Instrument table  

---

## Minimal Admin UI (not Phase 12)

- `/insights` — list / create-edit / publish toggle / delete  
- `/announcements` — list / create-edit / schedule / publish / delete  
- `/app-settings` — per-platform upsert form  
- Shell nav under 运营配置  

---

## Minimal Flutter (not Phase 13)

- `InsightArticlesService` + Wealth Insights prefers structured list  
- `AnnouncementsService` + `AppClientSettingsService` models only  
- Settings parse failures → `forceUpdate=false`, `maintenanceMode=false`  
- No force-update / maintenance blocking UI; no Home announcement stack  

---

## Tests

- API: `ops-content.service.spec.ts` (insights/announcements/settings + audit + auth filters)  
- Migration: additive SQL inspection (no DROP TABLE/COLUMN/TRUNCATE)  
- Flutter: `ops_content_models_test.dart` (+ existing app content tests)  

---

## Remains for Phase 12 / 13

| Phase | Scope |
|-------|--------|
| 12 | Full Admin UX (publish workflows, KV hygiene, audit viewer, SUPPORT sections) |
| 13 | Full Flutter consumption (announcement surfaces, force-update/maintenance UI, PackageInfo wiring) |

**Out of scope forever for this track:** trading / KYC / funds / market provider changes via CMS.

---

*End of Phase 11B.*
