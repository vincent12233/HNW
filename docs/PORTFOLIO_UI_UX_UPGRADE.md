# Portfolio UI / UX Upgrade (Phase 8)

Presentation-only. No portfolio math, holdings accounting, or API changes.

**Scope:** Product Portfolio tab (`ProductPortfolioPage`) — Institutional · OTC · IPO.  
Trade → **Positions** remains a separate surface (all settled lots including equity).

## Before

| Item | State |
|------|--------|
| Hierarchy | Flat: hero + summary + allocation + details + performance + activity (similar visual weight) |
| Empty | Hero still shown with zeros; empty CTA inside Allocation; zero category rows still listed |
| Colors | 7× `Color(0x…)` + AppConfig / Colors.white70 |
| Holdings | Material `Card` push route |
| Tokens | Minimal Design System usage |

## After

| Item | State |
|------|--------|
| **PRIMARY** | Hero: Total Portfolio Value, Total Returns, period chips, hide balances, sparkline |
| **SECONDARY** | Investment Summary `AppCard`: Current Value, Invested, Total Returns |
| **DETAIL** | Asset Allocation (donut + legend), Asset Details, Performance, Recent Activity — gated when empty |
| Empty | `AppEmptyState` + Explore (`onExplore` → Trade); no zero donut / clutter |
| Allocation palette | Limited: Institutional=`brandPrimary`, OTC=`gain`, IPO=`warning` |
| P&L | `AppColors.gain` / `loss` / `textSecondary` (zero); tabular numeric styles |
| Holdings sheet | `AppCard` rows; same fields |
| Hardcoded hex | **7 → 0** |

## Metrics (unchanged sources)

| UI | Field |
|----|--------|
| Total Portfolio Value | `currentValue` |
| Total Returns | `totalPnl` |
| Invested | `invested` |
| Unrealized / Realized P&L | `unrealizedPnl` / `realizedPnl` |
| Allocation | `categories[].allocationPercent`, `currentValue` |
| Holdings | `positions[]` (qty, availableQuantity, averagePrice, currentValue, unrealizedPnl) |

**Not on this page:** Available cash / Frozen margin (account funds live on Home / Trade). Do not invent them here.

## Portfolio vs Positions

| Surface | Meaning |
|---------|---------|
| Portfolio tab | Product book (Institutional · OTC · IPO) |
| Trade → Positions | Settled trading lots (includes equity) |

Data sources remain separate. No merge.

## Empty / Error / Loading

- Loading: linear indicator + RefreshIndicator
- Empty: `positionCount == 0` → AppEmptyState + Explore
- Error: message + Retry; same-period reload keeps prior data when possible
- Period switch: clears then reloads (existing test contract)

## Responsive / Accessibility

- Period chips scroll horizontally
- Allocation stacks on narrow / large text
- P&L not color-only (signed money via formatters + gain/loss text color)
- IconButtons retain theme min size

## Tests

- `flutter test test/product_portfolio_page_test.dart`
- `flutter analyze` / full `flutter test`
- `flutter build web --dart-define=API_BASE_URL=http://localhost:3000` — LOCAL BUILD VALIDATION ONLY
