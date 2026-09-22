# App Content Phase 13 — Flutter Dynamic Content & App Settings

**Status:** Complete (client integration).  
**Baseline before phase:** `03da9ca`  
**No production migration / deploy.**

---

## Startup & App Settings

| Step | Behavior |
|------|----------|
| Platform | `kIsWeb`→WEB, Android→ANDROID, iOS→IOS |
| Version | `package_info_plus` (fallback `AppConfig.appVersion`) — **not** CMS About marketing label |
| Fetch | `GET /app-settings?platform=` at bootstrap (`main`) |
| Cache | Memory via `AppClientSettingsService` ChangeNotifier |
| API failure | `forceUpdate=false`, `maintenanceMode=false` — continue |

### Gates (priority)

1. **Force update** if `current < minVersion` AND `forceUpdate`
2. Else **Maintenance** if `maintenanceMode`
3. Else **Optional update** if `current < latestVersion` (session dismissible dialog)

Invalid/unparseable current version → **no lock**.

### Store URL gap

`AppClientSetting` exposes `supportUrl` only (no `storeUrl`). Force-update UI offers Support link + Retry; does **not** invent Play/App Store URLs.

---

## Insights

- Structured `GET /insights` first via `listResult()` (SUCCESS vs FAILURE)
- **SUCCESS []** → empty state (no legacy KV)
- **FAILURE** → legacy KV `article.*` → local static
- Locale: en/hi request; server may return en fallback

---

## Announcements

- Home: at most **one** top live announcement under Market Status
- Types: subtle icon/accent (GENERAL / MAINTENANCE / IMPORTANT / MARKET_NOTICE)
- Bottom sheet detail on tap — not full-screen spam
- Distinct from Market News

---

## Featured instruments

- Public API: `GET /market/instruments?featuredHome=true|featuredMarkets=true&type=EQUITY&limit=`
- Home Featured section (hidden if empty)
- Markets Featured section (hidden if empty)
- Prices from live quote payload; unavailable → “Unavailable”
- Tap → same `StockDetailPage` / Buy-Sell flow
- Instrument remains sole catalog source

---

## KV content

Unchanged consumers for Home/Deposit/Support/Trading/Legal/About via `AppContentService`. Support desk tags/quick replies remain admin-only.

---

## Offline / loading

- Settings bootstrap is soft-fail
- Insights/Announcements/Featured load lazy after Home shell
- No fake financial data

---

## Security

Plain-text CMS bodies (SelectableText / Text). No HTML injection.

---

## Tests

- Version compare / gate priority / optional dismiss
- Announcement pick / expired filter
- Insights SUCCESS [] vs FAILURE legacy
- API: ops-content + public featured DTO
- `flutter analyze` / `flutter test` / web build with localhost define

---

## Remaining gaps

| Gap | Notes |
|-----|--------|
| Store URL field | Not in schema — Force Update uses supportUrl + Retry |
| Risk Disclosure | Admin/App surfaces implemented; compliance review still required before production |
| Device/emulator E2E | Report actual availability in Phase 13 report |
| Analytics | Not added |

---

*End of Phase 13.*
