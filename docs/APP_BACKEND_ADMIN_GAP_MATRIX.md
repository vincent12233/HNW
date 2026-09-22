# APP ↔ API ↔ Admin Gap Matrix

**Date:** 2026-09-16  
**Branch:** `cursor/app-ui-ux-admin-upgrade-c5d7`  
**HEAD at audit:** `bf704eeb359c4a8b8f267b64d917f87169a1024f`  
**Scope:** `apps/client`, `apps/api`, `apps/admin` (read-only).

## Status legend

| Status | Meaning |
|--------|---------|
| COMPLETE | App + API + Admin adequately wired |
| CONFIGURABLE | Driven by app-content CMS / env |
| PARTIAL | Some layer missing or incomplete |
| CLIENT_ONLY | App UI without full backend/admin |
| API_ONLY | Backend exists; little/no client (or mismatch) use |
| ADMIN_MISSING | App+API exist; no ops UI for that concern |
| HARDCODED | Client-fixed data/labels not CMS/admin managed |
| DEAD | Present but unused, empty, or intentionally blocked |
| CONFIGURABLE | Ops can edit via CMS/admin (may also be COMPLETE) |

---

## Focus matrix

| APP feature | API | Admin | Status | Notes / recommendation |
|-------------|-----|-------|--------|------------------------|
| Home banner title/subtitle | `GET /app-content` HOME `banner.*` | `/app-content` Home | CONFIGURABLE | Text only; no image carousel CMS |
| Markets banner | HOME `markets.banner.*` | `/app-content` | CONFIGURABLE | Text only |
| Company showcase | `GET /company-showcase` | `/company-showcase` | COMPLETE | CTA labels via HOME `company.*` |
| Home indices | `/market-data/indices`, session, socket | Instruments / market | PARTIAL | Titles CMS; index set hardcoded |
| Home asset / fund CTAs | `/account/portfolio`, assets history | Finance / deposits | COMPLETE + CONFIGURABLE | Add Funds → support chat (by design) |
| Home / Markets news | `/market-data/news` (RSS) | **NONE** | ADMIN_MISSING | Titles CMS; articles from RSS/env |
| In-app announcements | No dedicated API | **NONE** | CLIENT_ONLY / HARDCODED | Only support hours notice + system notifications |
| User watchlist | `/watchlist` CRUD | Admin watchlist = institutional listing | PARTIAL | User lists not admin-managed (OK) |
| Featured stocks (home sparks) | `/market-data/home` + history | Instrument `displayOrder` | HARDCODED | Client hardcodes symbol set for history sparks |
| Stock search / catalog | `/market-data/search` | `/instruments` | COMPLETE | Visibility via instrument master |
| Markets sectors | Quote `category` grouping | Instrument categories | HARDCODED / PARTIAL | No sector CMS |
| Markets F&O / Commodities / Currency | Category filter | Catalog could enable | HARDCODED | Tabs usually empty |
| Markets ETFs | Heuristic category | Instruments | PARTIAL | Keyword heuristics |
| Learning / Wealth Insights | INSIGHTS app-content | `/app-content` Insights | CONFIGURABLE | Client still has hardcoded article fallbacks |
| Privacy / Terms / Risk | LEGAL documents | `/app-content` Legal | CONFIGURABLE | English/Hindi editor; operator must provide translations and compliance approval |
| About Us | ABOUT keys | `/app-content` About | CONFIGURABLE | Entity fields still require operator data |
| Support UI copy | SUPPORT CMS | `/app-content` Support | CONFIGURABLE | Greeting, hours, topics, presets |
| Support live chat | SaleSmartly (CMS script URL / env) | Script URL in CMS; Nest `/support-console` separate | PARTIAL | **App does not call Nest `/support/*`** |
| Account recovery | `/auth/recovery*`, `/support/recovery*` | Support recovery | PARTIAL | Password recovery path only |
| Deposit page copy | DEPOSIT CMS | `/app-content` Deposit | CONFIGURABLE | |
| Deposit self-serve submit | `POST /deposit/request` → reject | — | DEAD (intentional) | Support-led funding |
| Deposit ops credit | Support submit + finance approve | `/deposits` etc. | COMPLETE | |
| Client bank accounts | `/client/bank-accounts` | `/bank-accounts` read | PARTIAL | Auto-approved create |
| Withdrawals | `/withdrawal/*` | `/withdrawals` | COMPLETE | Copy via HOME `withdraw.*` |
| Stock visibility / order | Market + instrument APIs | `/instruments`, `/market` | COMPLETE | |
| Institutional stocks | `/market-data/institutional` | `/watchlist` listing | COMPLETE | |
| OTC | `/otc/*` | `/block-trades`, business OTC | COMPLETE | |
| IPO open/apply | `/ipo/*` | IPO management / business IPO | COMPLETE | |
| IPO debts | Nested on applications; `/ipo/debts/me` unused by client | `/ipo-debts` | PARTIAL | Client should optionally use debts API |
| Equity orders / cancel | `/orders`, cancel | `/orders` | COMPLETE | **Do not change matching rules** |
| Order trades list | `GET /orders/trades` | `/trades` | API_ONLY | Client History uses orders filter |
| Holdings | Portfolio + positions | Business positions | COMPLETE | |
| Product portfolio | `/client/portfolio/products` | Positions / products | COMPLETE | |
| Profile / security / 2FA / PIN | `/client/*` | Customers / tier | COMPLETE | |
| KYC | `/kyc/*` | Business/team KYC | COMPLETE | **Do not change KYC rules** |
| Notifications inbox | `/client/notifications*` | **No broadcast composer** | ADMIN_MISSING | Domain-triggered only |
| Loans | `/loans/*` | `/loans` | COMPLETE | |
| Funds products | Admin products funds | `/funds` | API_ONLY | No Flutter surface |
| Quant strategies | Admin products quant | `/quant` | API_ONLY | No Flutter surface |
| Empty Nest `/stocks` module | Empty controller | NONE | DEAD | |
| `account/allocation`, `account/me` | Present | Indirect | API_ONLY | Client unused |
| IPO application-limit | Present | — | API_ONLY | Client unused |

---

## Client service → API map

| Service | Primary endpoints |
|---------|-------------------|
| `auth_service.dart` | `/auth/*`, `/kyc/*`, withdrawal request/me |
| `app_content_service.dart` | `GET /app-content` |
| `market_data_service.dart` | `/market-data/*`, `/company-showcase` |
| `market_socket_service.dart` | Market WS |
| `watchlist_service.dart` | `/watchlist` |
| `trading_service.dart` | `/account/portfolio`, `/account/transactions`, `/orders` |
| `ipo_service.dart` | `/ipo/open`, apply, applications/me |
| `otc_service.dart` | `/otc/offers`, OTC orders |
| `client_account_service.dart` | `/client/*`, `/loans/*`, kyc status |
| `salesmartly_*.dart` | External SaleSmartly SDK (not Nest `/support`) |

---

## Existing app-content CMS modules

| Module | Examples | Admin UI |
|--------|----------|----------|
| HOME | Banner, company CTAs, funds labels, indices/news titles, profile tiles, withdraw dialog | `/app-content` |
| DEPOSIT | Instructions, CTA, chat preset, history empty, terms | `/app-content` |
| SUPPORT | FAB, greeting, hours, topics, SaleSmartly script URL, zh quick replies | `/app-content` |
| TRADING | Tab labels, empty states, IPO confirm, portfolio labels, guides | `/app-content` |
| LEGAL | Privacy/Terms documents (EN) | `/app-content` |
| ABOUT | Company name, legal name, address, grievance, version, summary | `/app-content` |
| INSIGHTS | Intro + articles 01–08 (en/hi) | `/app-content` |

Company **media** is separate: `/company-showcase` (not app-content keys).

---

## APP content recommended for Super Admin (later phases)

Should be admin-maintained (mark CONFIGURABLE / expand CMS):

1. Home banners (consider image/carousel later)
2. Announcements / maintenance message
3. Featured / recommended stocks (replace hardcoded symbol lists)
4. Home section visibility & ordering
5. Markets featured categories / hide empty tabs
6. Learning Center / Wealth Insights (already partial)
7. FAQ (if product wants it)
8. Privacy / Terms / Risk disclosure (HI + launch-ready entity fields)
9. Company introduction / About
10. Support information + SaleSmartly Script URL (already)
11. Deposit instructions / presets (already)
12. App introduction / force-update / min version (missing today)
13. Some operational UI strings already in CMS — continue that path

**Should stay client-local:** core nav labels, form field names, trading field labels, generic system errors, button verbs.

---

## Highest-priority gaps

1. **Support dual-stack:** Nest `/support/*` + admin console vs Flutter SaleSmartly — document and decide; do not delete either without migration plan.
2. **No news / announcement ops CMS.**
3. **Funds / Quant** admin products with zero client surface — leave unless product wants client funds/quant.
4. **Hardcoded featured symbols + empty Markets tabs.**
5. **Legal/About launch readiness** (empty entity fields; HI legal).
6. **Unused client APIs:** `/orders/trades`, `/ipo/debts/me`, allocation, deposit self-serve, empty `/stocks`.

---

## Business logic unchanged (explicit)

This audit does **not** propose changes to: matching/撮合, freeze/unfreeze, order state machine, KYC rules, deposit/withdraw business rules, or live market data → mock substitution.

---

## Out of scope this phase

No code changes. Implementation deferred to later phases after product confirmation.
