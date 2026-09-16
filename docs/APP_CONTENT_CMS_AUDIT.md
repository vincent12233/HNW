# App Content CMS Audit (Phase 10)

> **Phase 11A updates (RESOLVED_11A):** ADMIN-only writes + AuditLog before/after; public locale fallback tightened to requested→en (no any); SUPPORT desk keys filtered from public GET (`/support/desk-content`); missing Flutter keys added; Positions/Overview/Product Holdings labels/defaults aligned without renaming keys; stale keys moved to Admin Legacy sections (DB rows kept); Admin save preserves isActive/sortOrder; About version clarified. See `docs/APP_CONTENT_PHASE_11A.md`.

**Scope:** Read-only audit of the existing Super Admin / App Content system.  
**Branch baseline:** `8bc8e52` (Phases 0–9 complete).  
**No code, Prisma, or migration changes in this phase.**

This document maps the real chain:

```
Flutter AppContentService
  → GET /app-content?locale=
Admin /app-content
  → GET /admin/app-content
  → POST /admin/app-content/bulk
    → AppContentService
      → Prisma AppContentEntry
```

**Do not assume CMS does not exist.** The system already ships modules HOME, DEPOSIT, SUPPORT, TRADING, LEGAL, ABOUT, INSIGHTS.

---

## 1. Existing stack (verified paths)

| Layer | Path | Notes |
|-------|------|-------|
| Admin UI | `apps/admin/app/app-content/page.tsx` | Static field defs; en/hi ops locale; ABOUT/LEGAL always save `en` |
| Admin nav | `apps/admin/components/AdminShell.tsx` | Menu `/app-content` under 运营配置; **ADMIN-only** |
| Admin API client | `apps/admin/lib/api.ts` | Axios; page uses GET list + POST bulk only |
| Controller | `apps/api/src/app-content/app-content.controller.ts` | Public + admin endpoints |
| Service | `apps/api/src/app-content/app-content.service.ts` | Defaults, locale pick, upsert, bulk, SaleSmartly sync |
| Defaults / seed | `apps/api/src/app-content/app-content.defaults.ts`, `prisma/seed.ts` | Lazy `ensureDefaults` + seed |
| Prisma | `AppContentEntry` + enum `AppContentModule` in `schema.prisma` | `@@unique([module, key, locale])` |
| Flutter | `apps/client/lib/services/app_content_service.dart` | Public GET; 5‑min memory cache; per-key fallbacks |
| Related (not key/value CMS) | `CompanyShowcase`, Market News RSS, Instrument `displayOrder` | Separate data planes |

### Prisma model (current)

```
enum AppContentModule { HOME DEPOSIT SUPPORT TRADING LEGAL ABOUT INSIGHTS }

model AppContentEntry {
  id, module, key, title?, body, locale (default "en"),
  metadata?, isActive (default true), sortOrder (default 0),
  createdAt, updatedAt
  @@unique([module, key, locale])
  @@map("app_content_entries")
}
```

### API endpoints (current)

| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| GET | `/app-content?locale=` | **None** | Public Flutter / support-console bundle |
| GET | `/admin/app-content?module=` | JWT + `@Roles(ADMIN)` | List all/filter |
| PUT | `/admin/app-content` | JWT + `@Roles(ADMIN)` | Single upsert |
| POST | `/admin/app-content/bulk` | JWT + `@Roles(ADMIN)` | Bulk upsert (Admin UI path) |
| DELETE | `/admin/app-content/:id` | JWT + `@Roles(ADMIN)` | Hard delete |

No class-validator DTO; service validates module enum + non-empty key/body. **No key allowlist** — any string key under a valid module can be written via API.

### Public bundle shape

`{ locale, home, deposit, support, trading, legal, about, insights, updatedAt }`  
Each module: `Record<key, { title, body, locale, metadata, sortOrder }>`.

### Locale pick (API)

**RESOLVED_11A:** Preferred locale with non-empty body → `en` non-empty → preferred empty → `en` empty.  
**No fallthrough to arbitrary locales** (prevents zh desk copy on hi/en clients). Keys with neither requested nor en content are omitted.  
Flutter then applies local string fallbacks if body still empty.

---

## 2. RBAC (from code — not guessed)

**Actual `UserRole` enum:** `ADMIN`, `MANAGER`, `BUSINESS`, `CLIENT`, `SUPPORT`, `FINANCE`.

**There is no `PLATFORM_ADMIN` or `SUPER_ADMIN` role in Prisma/API.**  
Admin UI labels `ADMIN` as “超级管理员” (`AdminShell.tsx`). Treat current `ADMIN` as the platform super-operator for this audit.

| Capability | ADMIN | MANAGER | BUSINESS | FINANCE | SUPPORT | Anon/CLIENT |
|------------|:-----:|:-------:|:--------:|:-------:|:-------:|:-----------:|
| Admin menu `/app-content` | Yes | No | No | No | No | No |
| GET `/admin/app-content` | Yes | No | No | No | No | No |
| Write PUT/bulk/DELETE | Yes | No | No | No | No | No |
| Per-module Legal vs Trading split | **No** — all modules same gate | — | — | — | — | — |
| Publish workflow | **N/A** — save forces `isActive: true` in Admin UI | — | — | — | — | — |
| GET `/app-content` public | Yes | Yes | Yes | Yes | Yes | **Yes** |

**Target design note (not implemented):** keep platform content writes to ADMIN-equivalent only; do not grant BUSINESS/FINANCE/SUPPORT write access to LEGAL / ABOUT / global SUPPORT script without an explicit product decision.

---

## 3. Audit log coverage

| Domain | Uses `AuditLog` / `AuditService`? |
|--------|-----------------------------------|
| Deposit / Withdrawal / IPO / Loans / Support tickets / Market instruments / Business | Yes (various services) |
| **App content upsert/bulk/delete** | **RESOLVED_11A** — AuditLog with before/after |

`AuditLog` fields: `actorId`, `action`, `resource`, `resourceId`, `description`, `metadata`, `createdAt`.  
Even if wired later, content writes today store **neither before nor after** snapshots.

**Gap:** operator / role / timestamp / before / after / module+key for content edits — **MISSING**.

---

## 4. Module inventory summary

| Module | Unique keys (defaults) | Locales in defaults | Admin UI | Flutter consume |
|--------|------------------------:|---------------------|----------|-----------------|
| HOME | 56 | en+hi | Yes | Mostly yes |
| DEPOSIT | 10 | en+hi | Yes | Mostly yes |
| SUPPORT | 17 | en+hi + zh admin-only | Yes | Client keys yes; zh no |
| TRADING | 33 | en+hi | Yes | Mostly yes |
| LEGAL | 2 | **en only** | Yes | Yes |
| ABOUT | 6 | **en only** | Yes | Yes |
| INSIGHTS | 10 (intro×2 + article.01–08) | en+hi | Yes | Yes |

Approx **~134 unique keys**; **~256 default rows** including articles×2 locales (defaults file expands articles via `flatMap`).

---

## 5. Master matrix

Status values: `COMPLETE` | `ADMIN_ONLY` | `CLIENT_ONLY` | `API_ONLY` | `STALE_CANDIDATE` | `DUPLICATE` | `OVER_CONFIGURED` | `MISSING` | `NEEDS_STRUCTURED_ENTITY`

### HOME

| Key / Entity | Admin | Flutter | EN | HI | Fallback | Status | Recommended | Risk | Target |
|--------------|:-----:|:-------:|:--:|:--:|----------|--------|-------------|------|--------|
| `banner.title` / `subtitle` | Y | Home hero | Y | Y | Local copy | COMPLETE | KEEP_AS_KEY_VALUE; later structured Banner entity | Low | 11B |
| `markets.banner.*` | Y | Markets page | Y | Y | Local | COMPLETE | KEEP_AS_KEY_VALUE / Banner entity | Low | 11B |
| `company.section_title` / CTAs | Y | Home company block | Y | Y | Local | COMPLETE | Labels KV; **media from CompanyShowcase** | Low | keep |
| `funds.cta_*` / `withdraw_cta_*` / `total_asset_label` | Y | Home funds | Y | Y | Local | COMPLETE | KEEP_AS_KEY_VALUE | Low | keep |
| `funds.available_label` | Y | **No** | Y | Y | — | STALE_CANDIDATE → **RESOLVED_11A** (Legacy Admin section; DB kept) | — | Low | done |
| `funds.trade_cta_label` / `subtitle` | Y | Home Trade CTA | Y | Y | Local | **RESOLVED_11A** | Added defaults + Admin | Low | done |
| `indices.section_title` / `view_all_cta` / `news.*` | Y | Home | Y | Y | Local; news empty ≠ fake news | COMPLETE | Labels only; **news items are RSS** | Low | keep |
| `profile.page_title` / `section.overview|security|preferences|support` | Y | Profile | Y | Y | Local | COMPLETE | KEEP; update Admin **labels** for Phase 4 names | Low | 11A |
| `profile.section.account|funds|legal` | Y | Profile sections | Y | Y | Local | **RESOLVED_11A** | Added defaults + Admin | Low | done |
| `profile.metric.*` | Y | Overview chips | Y | Y | Local (“Product Holdings”) | COMPLETE | Keep key; Admin default body already product-oriented | Low | 11A copy |
| `profile.tile.*` / logout | Y | Profile tiles | Y | Y | Local | COMPLETE | KEEP | Low | keep |
| Alert Preferences / Appearance / Language / KYC / Bank / PIN rows | **No** | Hardcoded titles | — | — | Local | CLIENT_ONLY | Optional Phase 11A keys; not required | Low | 11A optional |
| `withdraw.*` (20 keys) | Y | Withdraw dialog | Y | Y | Local (min ₹100 etc.) | COMPLETE / mild OVER_CONFIGURED | Keep UX copy; **do not** let CMS change real min amount logic | Med | 11A review |
| Market News items | N/A | Market news API | — | — | Empty + retry | KEEP_OUT_OF_CMS | External RSS — not AppContent | — | — |
| CompanyShowcase records | Separate admin | Home company cards | — | — | — | NEEDS_STRUCTURED_ENTITY (exists) | Keep separate from KV | — | keep |
| Platform Announcement | **Missing** | — | — | — | — | MISSING | New structured entity later | — | 11B |
| Featured stocks | Instrument `displayOrder`+`isActive` | Home/Markets lists | — | — | — | KEEP_OUT_OF_CMS (Instrument) | Extend flags on Instrument — **no second stock table** | — | 11B design |

### DEPOSIT

| Key | Admin | Flutter | Status | Notes |
|-----|:-----:|:-------:|--------|-------|
| `page_title`, `hero_title`, `instructions`, `cta_label`, `chat_preset`, `history_*`, `terms_*` | Y | Deposit page | COMPLETE | Client deposit ≠ KYC bank account (unchanged) |
| `api_reject_message` | Y | **No** (API `DepositController` reject) | ADMIN_ONLY / API_ONLY | Correct — server message when client deposit API rejects |

**Verdict:** DEPOSIT CMS is **partially complete** for UX copy; business rails not in CMS (good).

### SUPPORT

| Key | Locale | Consumer | Status |
|-----|--------|----------|--------|
| `salesmartly_script_url` | en/hi (synced) | Flutter chat + env fallback | COMPLETE — CLIENT CONFIG |
| `greeting`, `hours`, `topics`, `presets`, `fab`, `header`, `composer_hint` | en/hi | Flutter | COMPLETE — CLIENT CONFIG |
| `tags`, `quick_reply.*` | **zh** | Admin support-console via public GET | ADMIN_ONLY — **must not ship to client as primary UX** |

### TRADING

| Key | Admin default / label | Flutter fallback | Status | Action |
|-----|----------------------|------------------|--------|--------|
| `tab.holdings` | Default/label **Positions** | Offline fallback **“Positions”** | **RESOLVED_11A** (stable key retained) | Keep key; Admin + defaults updated |
| `tab.all` | “Overview” | Fallback **“Overview”** | **RESOLVED_11A** | Keep key; Admin + defaults updated |
| `shortcut.overview` | Y | Used | **RESOLVED_11A** | Added |
| `shortcut.orders` | Y | Y | COMPLETE | keep |
| Other `tab.*` | Y | Y | COMPLETE | Labels only |
| Empty states / portfolio headings / explore CTA | Y | Y | COMPLETE | keep |
| `portfolio.value_label` | Y (Legacy) | **No** | **RESOLVED_11A** (Legacy section; DB kept) | — |
| `portfolio.page_subtitle` | Y | Y | **RESOLVED_11A** | Added |
| `guide.institutional|otc|ipo` | Title+body editable | Shown if non-empty | OVER_CONFIGURED risk | Copy-only; ops can drift from engine rules |
| `ipo.confirm_template` | Editable | Used | OVER_CONFIGURED risk | Template must not invent payment automation facts |
| Order type / matching / freeze / limits | Not in CMS as controls | Hardcoded engines | KEEP_OUT_OF_CMS | — |

### LEGAL

| Key | Admin | Flutter | HI | Status |
|-----|:-----:|:-------:|:--:|--------|
| `privacy.document` | Y (JSON) | `LegalPage` + hardcoded fallback | Missing CMS | COMPLETE for en; hi falls to en then local |
| `terms.document` | Y (JSON) | Same | Missing CMS | COMPLETE for en |
| Risk Disclosure | **No** | **No page** | — | MISSING / ADMIN_MISSING | Document only — do not add in Phase 10 |

### ABOUT

| Key | Notes | Status |
|-----|-------|--------|
| `company_name`, `legal_name`, `registered_address`, `grievance_contact`, `summary` | Flutter About sheet | COMPLETE (en) |
| `app_version` | CMS body default `Version 1.0.0`; Flutter fallback same; **not PackageInfo** | OVER_CONFIGURED / confusion | Prefer build metadata; CMS may keep marketing “release note” separately |

### INSIGHTS

| Entity | Current | Status | Recommendation |
|--------|---------|--------|----------------|
| `intro.title` / `intro.body` | KV | COMPLETE | KEEP_AS_KEY_VALUE short-term |
| `article.01` … `article.08` | Fixed 8 title+body rows | NEEDS_STRUCTURED_ENTITY | Phase 11B: `id, slug, locale, title, summary, body, image?, published, sortOrder, publishedAt` |
| Local `wealthInsightArticles` | 8 hardcoded tuples | Fallback safety | Keep until structured API |

---

## 6. Phase 4–9 rename vs CMS keys

| UI (Phases 4–9) | CMS key | Current CMS body/label | Action |
|-----------------|---------|------------------------|--------|
| Positions | `trading.tab.holdings` | Positions | **RESOLVED_11A** |
| Overview (product filter) | `trading.tab.all` | Overview | **RESOLVED_11A** |
| Overview shortcut | `trading.shortcut.overview` | Overview | **RESOLVED_11A** |
| Alert Preferences | (none) | Hardcoded | Optional CMS later |
| Appearance | (none) | Hardcoded | Optional CMS later |
| Product Holdings metric | `home.profile.metric.portfolio` | Product Holdings | **RESOLVED_11A** |
| Profile Account / Funds / Legal sections | `profile.section.account|funds|legal` | Present | **RESOLVED_11A** |

**Rule:** do not rename stable API keys without a migration plan; prefer Admin label + default body updates.

---

## 7. What must NOT be CMS-editable

| Category | Examples | Current CMS? |
|----------|----------|--------------|
| Fixed primary nav IA | Home/Markets/Trade/Portfolio/Profile route structure | Not CMS (good) |
| Buy/Sell / Market/Limit / order status enums | Engine + client enums | Not CMS (good) |
| Matching / freeze / limits / accounting | Services | Not CMS (good) |
| KYC field requirements | KYC flow | Not CMS (good) |
| AuthZ / security errors | Nest exceptions | Not CMS (good) |
| Financial calculations | Balances, P&L | Not CMS (good) |
| Market provider / price source | Market-data services | Not CMS (good) |
| Arbitrary API URLs | Except intentional `salesmartly_script_url` | Partial — script URL is intentional CLIENT CONFIG |
| Role names | UserRole | Not CMS (good) |
| Educational text that restates product rules | Guides + Insights articles + Terms JSON | **Present — OVER_CONFIGURED risk** |

---

## 8. Structured content recommendations

| Need | Recommendation | Why |
|------|----------------|-----|
| Home/Markets banner copy | KEEP_AS_KEY_VALUE now; MOVE_TO_STRUCTURED_ENTITY later (image, link, schedule, locale) | Today title/subtitle only |
| Announcements | MOVE_TO_STRUCTURED_ENTITY (new) | Distinct from Market News & Banner |
| Market News | KEEP_OUT_OF_CMS | RSS / external in `market-news.service` |
| Featured stocks | KEEP_OUT_OF_CMS on Instrument; optional flags `featuredHome` / `featuredMarkets` later | Already `displayOrder` + `isActive`; **no second stock table** |
| Insights / Learning articles | MOVE_TO_STRUCTURED_ENTITY | Fixed `article.01`–`08` is debt |
| Company showcase | Already structured (`CompanyShowcase`) | Keep |
| Maintenance / min version / force update | MOVE_TO_STRUCTURED_ENTITY (AppSettings) | **Missing today** |
| Tab/empty/profile labels | KEEP_AS_KEY_VALUE | Fit current model |
| Legal documents | KEEP_AS_KEY_VALUE JSON short-term; structured docs later | en-only gap for hi |

### Announcement vs News vs Banner

| Concept | Meaning | Current |
|---------|---------|---------|
| Market News | External/market headlines | RSS service — not AppContent |
| Announcement | Platform ops notice | **Missing** |
| Banner | Marketing/entry visual + copy | HOME/MARKETS title-subtitle KV only |

Do not merge these three concepts.

### App settings (missing — design only)

Suggested future entity (not implemented):

```
platform: ANDROID | IOS | WEB
minVersion, latestVersion
forceUpdate: boolean
maintenanceMode: boolean
maintenanceMessage: string (locale-aware)
```

Company video remains CompanyShowcase / content CTAs — not confused with app version.

---

## 9. Language & fallback safety

| Locale | Coverage |
|--------|----------|
| en | Full defaults for all modules |
| hi | HOME/DEPOSIT/SUPPORT(client)/TRADING/INSIGHTS; **not** LEGAL/ABOUT |
| zh | SUPPORT tags + quick_reply only (admin console) |

**Flutter CMS outage behavior:** previous in-memory bundle or empty; every UI string has local fallback; **no fake prices/balances/news/orders**. Trading APIs independent — **core trading remains usable**. Support chat may fail if script URL unavailable from CMS/env/dart-define.

**Recommended chain (already largely true):** requested locale → en → local safe static UI copy.

---

## 10. Future phase split (no implementation here)

### PHASE 11A — Key/value cleanup & mappings
- Add missing Admin/default keys Flutter already reads
- Mark STALE_CANDIDATE keys; hide from Admin UI first (do not hard-delete without review)
- Align Admin labels/defaults for Positions / Overview / Product Holdings
- Optional: Alert Preferences / Appearance as CMS keys
- Wire content writes into AuditLog (before/after)
- Consider LEGAL/ABOUT hi rows
- Clarify `about.app_version` vs PackageInfo

### PHASE 11B — Structured entities (only where justified)
- Insights Article entity
- Optional Banner / Announcement entities
- AppSettings (maintenance / min version / force update per platform)
- Instrument feature flags extension (not a new stock table)

### PHASE 12 — Super Admin UI improvements
- Module RBAC polish (if roles expand)
- Publish/unpublish, sortOrder UI, stale key hygiene
- Separate CLIENT SUPPORT config vs zh console quick replies
- Diff preview / audit viewer

### PHASE 13 — Flutter dynamic-content completion
- Consume new structured endpoints
- Prefer PackageInfo for version
- Fill remaining hardcoded Profile row titles if product wants CMS
- Risk Disclosure only if legal + Admin + client surfaces exist

---

## 11. Evidence checklist

| Claim | Evidence |
|-------|----------|
| CMS exists | Admin page + Prisma model + Nest module |
| ADMIN-only writes | `@Roles(UserRole.ADMIN)` on admin routes |
| No PLATFORM_ADMIN/SUPER_ADMIN | `UserRole` enum in schema |
| No content audit | No AuditService in `app-content` |
| Public unauthenticated read | `@Get('app-content')` ungarded |
| Featured = Instrument order | `market-data.service` `findMany` orderBy `displayOrder` |
| Insights fixed 8 | `article.01`–`08` in defaults + Admin |
| Risk Disclosure absent | No client page / no LEGAL key |

---

*Phase 10 deliverable only. Do not treat recommendations as authorization to migrate schema.*
