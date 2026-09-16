# App Content Target Architecture

**Status:** Phase 10–13 complete for App Content track (KV + structured entities + Admin UX + Flutter integration).  
**Prerequisite audit:** `docs/APP_CONTENT_CMS_AUDIT.md`  
**Phase docs:** `APP_CONTENT_PHASE_11A.md`, `APP_CONTENT_PHASE_11B.md`, `APP_CONTENT_PHASE_12_ADMIN.md`, `APP_CONTENT_PHASE_13_CLIENT.md`, `APP_CONTENT_END_TO_END_MATRIX.md`

Goal: **reuse and normalize** the existing App Content system — do not build a parallel CMS.

---

## 1. Target data flow

```
┌─────────────────────┐         ┌──────────────────────────┐
│ Flutter Client      │         │ Super Admin (apps/admin) │
│ AppContentService   │         │ /app-content (+ future)  │
└─────────┬───────────┘         └────────────┬─────────────┘
          │                                  │
          ▼                                  ▼
   Public Content API              Authenticated Admin Content API
   GET /app-content                GET/PUT/POST/DELETE /admin/app-content*
          │                                  │
          └──────────────┬───────────────────┘
                         ▼
              Validated Content Service
              (module allowlists, locale,
               publish rules, audit hooks)
                         ▼
                    PostgreSQL
              AppContentEntry (+ future
              structured tables)
```

### Hard rules

1. **Flutter never talks to the database.**
2. **Admin UI never bypasses the API** (no direct DB / Prisma from Next).
3. **One content service** serves both public and admin surfaces.
4. **Reuse** `AppContentModule` / `AppContentEntry` for key/value copy unless a structured entity is justified.
5. CMS outage must not invent financial data; client keeps safe static UI fallbacks.

---

## 2. What already matches the target

| Piece | Current state | Keep? |
|-------|---------------|-------|
| Public bundle API | `GET /app-content` | Yes (add caching/CDN later if needed) |
| Admin list + bulk | `GET /admin/app-content`, `POST .../bulk` | Yes |
| Single Prisma model | `AppContentEntry` | Yes for KV |
| Locale columns | `locale` + unique `(module,key,locale)` | Yes |
| Flutter service + fallbacks | `AppContentService` | Yes — strengthen, don’t replace |
| CompanyShowcase | Separate structured entity | Yes — do not fold into KV |
| Instrument `displayOrder` / `isActive` / `featuredHome` / `featuredMarkets` | Featured surfaces | Yes — flags on Instrument only |
| Market News RSS | Separate service | Yes — not AppContent |
| InsightArticle / Announcement / AppClientSetting | Structured ops content (11B) | Yes — keep KV for labels |

---

## 3. Gaps vs target

| Gap | Impact | Planned phase |
|-----|--------|---------------|
| No AuditLog on content writes | Ops changes untraceable | 11A |
| No key allowlist on API | Arbitrary keys / drift | 11A |
| Admin forces `isActive: true` | No draft/publish | 12 |
| Fixed Insights `article.01`–`08` | Poor editorial UX | **11B done** (structured + KV fallback) |
| No Announcement entity | Ops notices missing or misused as “news” | **11B done** |
| Banner only title/subtitle | No image/link/schedule | **11B: KEEP_AS_KV** until real need |
| No AppSettings (maintenance / min version) | Cannot safely gate clients | **11B done** (API + model; UI gate in 13) |
| LEGAL/ABOUT en-only in CMS | hi relies on API→en→local | 11A |
| Role names vs product language | Code has `ADMIN` only (UI: 超级管理员); no PLATFORM_ADMIN/SUPER_ADMIN | Document; optional role rename later — **out of Phase 10** |
| `about.app_version` is CMS copy | Can diverge from build | 11A / 13 |
| Rename drift (Holdings vs Positions) | Admin defaults lag Flutter | 11A |
| Guides/Terms can restate trading rules | OVER_CONFIGURED risk | 11A policy + 12 UI warnings |

---

## 4. Content class model (target)

### A. Key/value display copy — stay on `AppContentEntry`

Use for:

- Section titles, button labels, empty states
- Profile tile titles (selected)
- Deposit/Support client UX strings
- Withdraw dialog labels (UX only)
- Legal document JSON blobs (short-term)

**Not for:** prices, balances, order state machines, instrument lists, provider config.

### B. Structured entities — new tables only when justified

| Entity | Fields (sketch) | Why not KV |
|--------|-----------------|------------|
| **InsightArticle** | id, slug, locale, title, summary, body, imageUrl?, isPublished, sortOrder, publishedAt | Editorial lifecycle; more than 8 fixed keys |
| **Announcement** | id, locale, title, body, severity, startsAt, endsAt, isPublished | Ops notices ≠ market news ≠ banner |
| **ContentBanner** (deferred) | — | **KEEP_AS_KV** in 11B; promote only if image/deepLink/schedule/multi needed |
| **AppClientSetting** | platform(ANDROID/IOS/WEB), minVersion, latestVersion, forceUpdate, maintenanceMode, maintenanceMessage, supportUrl? | Safety-critical client gates |

### C. Existing non-CMS structured (keep)

| Entity | Role |
|--------|------|
| `Instrument` | Catalog; featured via `displayOrder` + `featuredHome` / `featuredMarkets` |
| `CompanyShowcase` | Home company cards + video/website |
| Market news feed | External headlines |

### D. Must stay out of CMS

Fixed nav IA, Buy/Sell semantics, Market/Limit meanings, order status enums, KYC requirements, auth errors, financial math, market provider config, balance/frozen accounting, role names, arbitrary secrets/URLs (except approved support script URL).

---

## 5. Admin vs client SUPPORT config

| Config | Audience | Storage |
|--------|----------|---------|
| `salesmartly_script_url`, greeting, hours, topics, client presets | **Client** | AppContent SUPPORT en/hi |
| `tags`, `quick_reply.*` (zh) | **Admin support console** | Keep separate conceptually; do not present as client App strings |

Phase 12 UI should visually separate “客户端客服文案” vs “后台坐席快捷回复”.

---

## 6. Featured stocks (Phase 11B choice)

**Do not create a second stock/content table.**

**Chosen:** Boolean flags on `Instrument`: `featuredHome`, `featuredMarkets` (+ keep `displayOrder` / `isActive`).

Tradability remains engine/`isActive` (and product rules), not a CMS free-text field.

---

## 7. Announcement / Banner / News separation

```
Market News     → external/market feed service (exists)
Announcement    → platform ops entity (`Announcement` — 11B)
Banner          → marketing/entry creative (HOME/MARKETS KV titles; KEEP_AS_KV)
```

Admin CMS must not dump announcements into `news.section_title` or Insights articles.

---

## 8. App settings & force-update safety (design)

Per platform row:

| Field | Rule |
|-------|------|
| `minVersion` | Semver; clients below → soft/hard gate |
| `latestVersion` | Informational / soft update |
| `forceUpdate` | If true and below min → blocking UI |
| `maintenanceMode` | Blocks trading UI with message; API may still enforce separately |
| `maintenanceMessage` | Locale-aware |

**Never** store this only as free-form HOME keys without validation.  
**Never** let BUSINESS roles flip force-update without ADMIN.

---

## 9. Locale strategy (target)

1. Authorative locales for client: **en**, **hi** (match Flutter `AppLanguage`).
2. Public API: requested → en → (client local fallback).
3. LEGAL/ABOUT: add hi rows when legal-approved; until then en + local fallback is acceptable.
4. zh SUPPORT quick replies remain admin-console locale, not a third client language.

---

## 10. RBAC target (align with real roles)

Until roles are renamed in schema:

| Action | Allowed roles (current enum) |
|--------|------------------------------|
| Read admin content | `ADMIN` |
| Edit app KV / publish | `ADMIN` |
| Edit LEGAL | `ADMIN` only |
| Edit SUPPORT client script URL | `ADMIN` |
| Edit zh console quick replies | `ADMIN` (or SUPPORT **read** via public GET today — write should stay ADMIN) |
| Featured instrument flags | `ADMIN` and/or existing market instrument editors (already audited elsewhere) |
| AppSettings / force update | `ADMIN` only |

If product later introduces `PLATFORM_ADMIN` / `SUPER_ADMIN`, map them explicitly; **do not invent them in docs as if they exist in code today.**

---

## 11. Audit target

Every admin content mutation:

| Field | Source |
|-------|--------|
| operator | JWT `sub` / actorId |
| role | user.role |
| timestamp | createdAt |
| module / key / locale / entity id | resource + metadata |
| before | previous row JSON |
| after | new row JSON |
| action | CREATE / UPDATE / DELETE / BULK |

Reuse existing `AuditLog` + `AuditService` — do not create a parallel audit product in Phase 10.

---

## 12. Phased delivery map

### PHASE 11A — Existing key/value cleanup & missing mappings
- Sync Admin field list ↔ Flutter consumers
- Fix Positions/Overview Admin labels & defaults (**keep keys**)
- Add missing keys Flutter already reads
- Hide STALE_CANDIDATE keys in Admin UI
- AuditLog before/after on upsert/bulk
- Optional LEGAL/ABOUT hi
- Clarify app version source
- Document OVER_CONFIGURED guide/terms policy

### PHASE 11B — Structured entities only where justified — **DONE**
- InsightArticle (+ legacy KV fallback / idempotent import)
- Announcement (Banner deferred as KEEP_AS_KV)
- AppClientSetting (maintenance / versions)
- Instrument `featuredHome` / `featuredMarkets` (no duplicate catalog)
- Minimal Admin pages + Flutter models/Insights smoke consumption
- See `docs/APP_CONTENT_PHASE_11B.md`

### PHASE 12 — Super Admin UI improvements — **DONE**
- APP Management nav + hub summary
- Content page sections / safety / Legacy Insights demotion
- Insights & Announcements formal management + preview
- App Settings danger confirmations
- Featured Instruments (Instrument flags + placement PATCH)
- See `docs/APP_CONTENT_PHASE_12_ADMIN.md`

### PHASE 13 — Flutter dynamic-content completion — **DONE**
- App settings bootstrap + force/maintenance/optional gates
- Insights SUCCESS[] vs FAILURE fallback
- Announcements Home banner (max 1)
- Featured Home/Markets via public instruments filters
- See `docs/APP_CONTENT_PHASE_13_CLIENT.md` + end-to-end matrix

**Remaining product gaps:** store URL field; Risk Disclosure; production release ops (out of this track).

---

## 13. Explicit non-goals for Phase 10–11A

- No Prisma migration in Phase 10
- No new CMS product alongside `AppContentEntry`
- No Flutter UI rewrite for content
- No Admin page large rewrite
- No trading / funds / KYC / provider changes via CMS

---

## 14. Success criteria (later phases)

1. Every Admin-editable key maps to a known Flutter (or API) consumer, or is marked stale.
2. Structured content uses entities; labels stay KV.
3. Content edits are auditable with before/after.
4. CMS outage does not block trading or invent money/market data.
5. Featured stocks remain Instrument-centric.
6. Announcements ≠ Market News ≠ Banners.

---

*End of Phase 10 architecture design.*
