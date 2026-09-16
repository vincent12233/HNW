# Trade UI / UX Upgrade (Phase 7)

Presentation-only. No TradingService, placeOrder payload, cancel, matching, balance, freeze, Decimal, or API-contract changes.

## Before

| Item | State |
|------|--------|
| Product row | All · Ins. Stock · OTC · IPO |
| Shortcuts | 4 dense icon buttons: Orders · Pending · Positions · History |
| Module indices | 0–8 retained (Trades, Institutional, Positions, Pending, Order Book, OTC, IPO, History, Funds Ledger) |
| Hero P&L | Hardcoded soft greens/pinks (`0xff70e0ba` / `0xffffa6b1`) |
| Notification badge | `Color(0xFFEF233C)` |
| Order status | Ad-hoc labels/colors (`Completed` for FILLED, hex/AppConfig) |
| Pending section | Visible title **Order Book** |
| Buy/Sell bar | AppConfig gain/loss + radius `10` + hex top border |
| Confirm dialog | “Confirm Buy Order” / “Confirm Sell Order” |
| Hardcoded hex (focus files) | trading_center dense; orders/history/pending/trade_list mixed slate hex |

## After

| Item | State |
|------|--------|
| Product row | **Overview** · Ins. Stock · OTC · IPO (CMS key `tab.all` fallback) |
| Shortcuts | Horizontally scrollable **ChoiceChip** row: Overview · Positions · Orders · Pending · History → indices **0, 2, 4, 3, 7** |
| Funds Ledger | Header wallet icon → index **8** (unchanged) |
| Hero P&L | `AppColors.chartGain` / `AppColors.loss` on brand gradient |
| Notification badge | `AppColors.loss` |
| Order status | `OrderStatusPresentation.label` + `AppStatusChip` (filter wire values unchanged) |
| Pending section | Title **Open orders** (UI string only) |
| Buy/Sell bar | `AppColors.buy` / `sell`, `AppRadius`, `AppSpacing` — same `setState(isBuy)` + `placeOrder()` |
| Confirm dialog | “Confirm Buy” / “Confirm Sell” |
| Tokens | AppColors / AppTypography / AppSpacing / AppRadius across Trade chrome |

## Tabs / modules

| Index | Module | Product row | Shortcut chip |
|------:|--------|-------------|---------------|
| 0 | Overview (`TradeList`) | Overview | Overview |
| 1 | Institutional | Ins. Stock | — |
| 2 | Positions | (via Overview group) | Positions |
| 3 | Pending | (via Overview group) | Pending |
| 4 | Orders | (via Overview group) | Orders |
| 5 | OTC | OTC | — |
| 6 | IPO | IPO | — |
| 7 | History | (via Overview group) | History |
| 8 | Funds Ledger | Header only | — |

Capabilities for all nine destinations unchanged. Refresh-failure banner retained.

## Buy / Sell

Sticky bar on `StockDetailPage` only: both buttons kept; BUY sets `isBuy = true` then `placeOrder()`; SELL sets `isBuy = false` then `placeOrder()`. Payload construction and validation gates in `market_page` / `placeOrder` unchanged.

## Statuses

Wire filters remain `ALL` / `OPEN` / `PARTIALLY_FILLED` / `FILLED` / `CANCELLED` / `REJECTED`. Display labels come from `OrderStatusPresentation` (e.g. FILLED → **Filled**, not “Completed”).

## Business logic unchanged

- No edits to `TradingService`, matching, balances, freeze, Decimal math, or API contracts
- Cancel flows and order refresh scheduling unchanged
- Data loading in Overview (`TradeList`) unchanged

## Hardcoded colors (focus files)

| File | Before | After |
|------|--------|-------|
| `trading_center_page.dart` | AppConfig + hex badge/P&L/shortcut teal | AppColors / AppTypography / AppSpacing |
| `orders_tab.dart` / `history_tab.dart` | Ad-hoc status hex + white/`0xFFE5E7EB` cards | Tokens + `AppStatusChip` |
| `pending_center_tab.dart` | Mixed hex / AppConfig | Tokens; section title string only |
| `stock_detail_page.dart` (bar) | AppConfig + `0xFFE8EDF5` | AppColors.buy/sell + AppRadius/Spacing |
| `trade_list.dart` | AppConfig + slate hex | Tokens + status presentation helper |

## Tests

From `apps/client`:

- `dart format` on changed files
- `flutter analyze`
- `flutter test` (incl. `trade_navigation_test` and trading-related)
