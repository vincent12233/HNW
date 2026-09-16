# APP UI / UX Audit

**Date:** 2026-09-16  
**Branch:** `cursor/app-ui-ux-admin-upgrade-c5d7`  
**HEAD at audit:** `bf704eeb359c4a8b8f267b64d917f87169a1024f`  
**Scope:** `apps/client/lib` (read-only). No application code changed in this phase.

## Summary

| Metric | Count |
|--------|------:|
| Page files under `lib/pages/` | 25 |
| Screen classes (incl. nested) | 26 |
| Bottom-nav root tabs | 5 |
| Trade inner tabs | 9 |
| Markets inner tabs | 8 |
| Profile tiles (excl. logout) | 16 |

**Routing model:** No GoRouter. Named routes `/` and `/register` only; all other navigation uses `Navigator` + `MaterialPageRoute`.

**Bottom navigation (keep):** Home · Markets · Trade · Portfolio · Profile

---

## Navigation map

```
MaterialApp
  '/' → AuthGate → Splash | Login | MarketHomePage (session)
  '/register' → RegisterPage

MarketHomePage (shell)
  0 Home      → market body (funds, indices, movers, news, showcase)
  1 Markets   → MarketsPage
  2 Trade     → TradingCenterPage
  3 Portfolio → ProductPortfolioPage
  4 Profile   → account body (menu tiles)
```

Support: FAB / Help / Deposit CTA → `showSupportChatPanel` → `SupportChatPage` (dialog).

---

## Full screen inventory

| Module | Screen | Route / entry | Client status | API status | Admin status | Data source | Problem | Recommendation | Delete / Keep / Merge / Improve | Priority |
|--------|--------|---------------|---------------|------------|--------------|-------------|---------|----------------|---------------------------------|----------|
| AUTH | SplashPage | AuthGate loading | Live | N/A | N/A | Local | None | Keep splash branding consistent later | Keep | P3 |
| AUTH | LoginPage | AuthGate / logout | Live | `/auth/login`, Google, biometric | N/A | API | Biometric “enable in Profile” has no Profile UI | Wire enable or remove claim | Improve | P1 |
| AUTH | RegisterPage | `/register`, Login link | Live | `/auth/register` | Invite codes | API | None material | Keep | Keep | P2 |
| AUTH | ForgotPasswordPage | Login link | Live | `/auth/password-reset/*`, recovery | Support recovery | API | None material | Keep | Keep | P2 |
| KYC | KycUploadPage | Post-auth KYC, Profile KYC | Live | `/kyc/submit`, `/kyc/status` | Business/team KYC | API + uploads | Multi-step dense UI | UX polish only; do not change KYC rules | Improve | P1 |
| KYC | SelfieCameraPage | From KYC | Live | Via KYC submit | Via KYC | Camera | None | Keep | Keep | P2 |
| KYC | BankDetailsPage | KYC / Profile banks | Live | `/client/bank-accounts` | Bank list (read) | API | Auto-approved create; no admin approve UI | Keep client; admin approve later | Improve | P2 |
| HOME | MarketHomePage (Home tab) | Bottom nav Home | Live | Portfolio, market-data, CMS, showcase | App-content, company-showcase, instruments | API + CMS | Section order dense; static banner text; hardcoded index symbols / featured history symbols | IA + CMS for sections; design polish | Improve | P0 |
| MARKETS | MarketsPage | Bottom nav Markets | Live | `/market-data/*`, watchlist | Instruments / market | API | Empty F&O/ETF/Commodity/Currency tabs; confusing vs Home | Hide empty tabs until catalog live | Merge / Improve | P1 |
| MARKETS | StockSearchPage | Home & Markets search | Live | `/market-data/search` | Instruments | API | None material | Keep | Keep | P2 |
| MARKETS | StockDetailPage | Stock taps | Live | Quotes, history, orders | Instruments | API | Shared from Home/Markets — good | Unify card density with lists | Improve | P1 |
| MARKETS | MarketNewsPage | Home news View all | Live | `/market-data/news` (RSS) | **None** | RSS/env | No admin CMS for news | Keep client; add admin later or document | Improve | P2 |
| TRADE | TradingCenterPage | Bottom nav Trade | Live | Orders, OTC, IPO, institutional, ledger | Orders, OTC, IPO, watchlist | API | 9 tabs high cognitive load | Group / clarify labels; **do not change trading logic** | Improve | P1 |
| TRADE | DepositPage | Home Add Funds | Live | CMS; deposit self-serve **rejected** | Deposits ops | CMS + tx history | Looks incomplete vs brokers; by design support-led | Clarify UX copy; keep business rule | Improve | P1 |
| PORTFOLIO | ProductPortfolioPage | Bottom nav Portfolio | Live | `/client/portfolio/products` | Positions / products | API | Holdings also on Trade — split is intentional but confusing | Clarify ordinary vs product holdings | Improve | P1 |
| PROFILE | Profile menu (in MarketHomePage) | Bottom nav Profile | Live | Profile APIs | Customers | API + CMS tiles | Long menu; some duplicate legal entries | Group & declutter | Improve | P0 |
| PROFILE | AccountSettingsPage | Profile tiles | Live | `/client/profile*`, banks, prefs | Customers | API | **`reconciliation` section has no nav entry** | Expose intentionally or remove later | Keep (flag) | P2 |
| PROFILE | AccountSecurityPage | Password / PIN tiles | Live | `/client/security/*` | Indirect | API | None material | Keep | Keep | P2 |
| PROFILE | TwoFactorPage | 2FA tile | Live | `/client/security` 2FA | Indirect | API | None | Keep | Keep | P2 |
| PROFILE | AppearancePage | Theme tile | Live | Prefs write | N/A | Local + API prefs | Separate from Preferences tile | Optional merge into Preferences | Merge | P3 |
| PROFILE | LanguagePage | Language tile | Live | Prefs | N/A | Local + API | Separate from Preferences | Optional merge | Merge | P3 |
| PROFILE | NotificationsPage | Header bell | Live | `/client/notifications*` | **No broadcast UI** | API | Inbox vs “Notification Settings” naming clash | Rename tiles | Improve | P2 |
| PROFILE | LoanPage | Loan Applications | Live | `/loans/*` | `/loans` | API | Niche; keep if product needs loans | Keep unless product sunsets loans | Keep | P3 |
| SUPPORT | SupportChatPage | FAB / Help / Deposit | Live | SaleSmartly JSSDK/native | Script URL in CMS; Nest support console separate | External SS + CMS | Dual-stack vs Nest `/support/*` | Keep SaleSmartly; document dual-stack | Keep | P1 |
| CONTENT | WealthInsightsPage | Profile Wealth Insights | Live | INSIGHTS CMS | App-content Insights | CMS + hardcoded fallbacks | Hardcoded article fallbacks | Prefer CMS; trim hardcode later | Improve | P2 |
| CONTENT | WealthInsightArticlePage | From insights list | Live | CMS | Insights | CMS | None | Keep | Keep | P3 |
| LEGAL | LegalPage | Terms / Privacy / About | Live | LEGAL CMS | App-content Legal | CMS + large EN fallbacks | HI legal missing; About entity fields often empty | CMS HI + fill About; polish UI | Improve | P1 |

---

## Finding categories

### A. Page duplicates
- Naming confusion: `market_page.dart` (`MarketHomePage`) vs `markets_page.dart` (`MarketsPage`) — different roles; rename later, do not delete.
- No true duplicate full-page clones.

### B. Feature duplicates
- Holdings: Trade → Holdings (ordinary) vs Portfolio (Inst/OTC/IPO) — intentional; clarify labels.
- Money history: Deposit history vs Trade → Funds Ledger.
- Legal: Profile Terms/Privacy **and** About sheet links.
- Support: FAB + Help tile + Deposit CTA (same panel — OK, multiple entry points).

### C. No entry
- `AccountSettingsPage(section: 'reconciliation')` — never opened from Profile.
- Biometric enable path claimed on Login; no Profile enable UI; `enableBiometricQuickLogin()` unused from UI.

### D. Dead code
- No orphan page files (all 25 referenced).
- Reconciliation UI section effectively unreachable.
- Empty `/stocks` Nest module is API-side (see gap matrix).

### E. Placeholders
- Markets tabs F&O / ETFs / Commodities / Currency often empty (“when enabled by catalog”).

### F. Mock data
- No fake price generators found.
- Hardcoded **content fallbacks** for legal + wealth articles when CMS empty (not market mocks).

### G. Deprecated-looking
- Deposit is support-led (not in-app payment) by design.
- `@Deprecated` field on institutional model — keep until product cleans models.

### H. Confusing UX
- “Notification Settings” opens Preferences (notification toggles only).
- Inbox Notifications vs Notification Settings.
- Login biometric without enable path.

### I. Duplicate settings
- Theme + Language separate from Preferences/notifications page.

### J. Internal items in client
- Reconciliation section looks ops-oriented; currently hidden (no nav) — do not surface without product decision.

### K. UI incomplete vs API
| Item | Issue |
|------|--------|
| Biometric enable | UI claim without enable entry |
| Markets empty tabs | Catalog not populated |
| Deposit self-serve | Intentionally API-rejected |

### L. Hardcoded operational content (CMS candidates)
- Legal Privacy/Terms large EN fallbacks
- Wealth Insights 8 bilingual fallback articles
- Home banner / section copy (partially CMS with fallbacks)
- Deposit instructions / terms (CMS with fallbacks)
- About legal entity fields often empty in CMS

---

## Confident delete / merge / keep

| Item | Action | Why |
|------|--------|-----|
| All 25 page files | **Keep** | Each has a live entry (except nested dead *section*) |
| Reconciliation section | **Keep + flag** | Uncertain product need; no nav today |
| Biometric enable | **Keep + flag** | Incomplete wiring |
| Empty Markets tabs | **Keep + flag** | Hide when empty in later IA phase |
| Appearance + Language into Preferences | **Merge (later)** | UX declutter only |
| True page deletes this phase | **None** | Insufficient confidence |

**Rule applied:** If uncertain → Keep and record. No deletions in Phase 1.

---

## UI / UX main issues (preview for later phases)

1. Dense Home without clear hierarchy.
2. Trade center tab overload (9 tabs).
3. Profile menu length and naming collisions.
4. Scattered colors / gradients (design system Phase 3).
5. Empty Markets category tabs reduce trust.
6. Support dual-stack (SaleSmartly vs Nest console) is operationally confusing — not a UI delete.

---

## Out of scope this phase

No Flutter/API/Admin code changes. Design system and navigation cleanup deferred to later phases.
