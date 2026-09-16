# Home UI / UX Upgrade (Phase 5)

Presentation-only upgrade of the Home tab. No trading, KYC, funds, or market-provider logic changes. Amounts still use existing `formatPrice` / `formatSignedPrice` / `formatIndex`.

## Before structure

1. MarketHeader (avatar, greeting, notifications, search)
2. MarketStatusCard
3. Funds composite:
   - Total Asset Value hero
   - Quick actions (Add Funds, Withdraw)
   - Our Company (when present) — competed with account hero
   - Available / Margin / Unrealized P&L strip
4. Market Indices
5. Top Gainers | Top Losers (5 each, logo-required)
6. Market News (2)
7. Non-tappable trading banner

## After structure

**PRIMARY**

1. MarketHeader (design tokens; wave emoji removed)
2. MarketStatusCard
3. Account summary:
   - Total Asset Value hero (tabular figures)
   - Quick actions: **Add Funds · Withdraw · Trade**
   - Available / Margin / Unrealized P&L in `AppCard`

**SECONDARY**

4. Market Indices (`AppCard` chips)
5. Top Gainers | Top Losers (3 each; logos optional; clearer type)
6. Market News (2 preview cards + unavailable/retry)

**TERTIARY**

7. Our Company (moved below news; compressed description)
8. Trading banner → taps to **Trade** tab

Also: Home pull-to-refresh (market + account + news).

---

## Changes summary

| Area | Change |
|------|--------|
| Removed visual clutter | Wave icon; 9px mover type; company inside funds; non-actionable banner |
| Moved | Company showcase → below news |
| Kept | Total asset, period returns, hide balances, IPO required line, indices set, news preview, status strip |
| Quick actions | 2 → 3 (added Trade → tab index 2) |
| Account summary | Same metrics; strip uses `AppCard`; hero uses tokens/tabular figures |
| Market | Indices/movers/news tokenized; movers take(3); empty copy clarified |
| Banner | Soft brand fill; navigates to Trade |
| Loading | Pull-to-refresh; section-level news retry; full-page load unchanged |
| Empty / Error | Movers: “No gainers/losers right now”; News: unavailable + Retry (not fake data) |

---

## Hardcoded content remaining (Admin CMS TODO)

| Item | Notes |
|------|-------|
| Index set (NIFTY 50, SENSEX, BANK NIFTY, INDIA VIX) | Client hardcoded list |
| `_shortStockName` map | Prefer API names / CMS aliases |
| Banner / section copy fallbacks | Already AppContent keys — ensure admin-editable + CTA URL |
| Markets featured symbols | Not Home UI; still hardcoded on Markets |
| NSE hours in MarketStatusCard | Client-side clock; server session unused |

**HARD-CODED CONTENT TODO** for Phases 10–13.

---

## Hardcoded UI colors

| Scope | Before (Phase 4 HEAD) | After |
|-------|----------------------|-------|
| `market_header.dart` | 7 | **0** |
| `market_page.dart` `Color(0x…)` | 44 | **20** |
| Home chrome (header + Home sections) | ~34 | **~1** (soft loss tint `#FCA5A5` on dark hero) |

Remaining in `market_page.dart`: withdraw dialog, membership/profile accents — outside Home section UI.

---

## Responsive / accessibility

- Horizontal padding: 14px under 360 width, else 16
- Movers stack vertically under 300px width
- News single column under 340px
- IconButtons keep ≥44dp themes from design system
- High contrast: Home inherits `AppTheme.highContrast()` (unchanged)
- Text scaling: existing app clamp 0.9–1.4

---

## Tests

- `dart format --set-exit-if-changed`
- `flutter analyze`
- `flutter test`
- `flutter build web --dart-define=API_BASE_URL=http://localhost:3000` — **LOCAL BUILD VALIDATION ONLY**

No emulator/device visual capture in this environment.
