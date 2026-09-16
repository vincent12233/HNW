# Markets UI / UX Upgrade (Phase 6)

Presentation-only. No market-provider, matching, or trading-logic changes.

## Before

| Item | State |
|------|--------|
| Tabs | 8 fixed: Watchlist, Indices, Stocks, Sectors, F&O, ETFs, Commodities, Currency |
| Empty catalog tabs | Always visible with “unavailable” shells |
| Search | Push to `StockSearchPage`; Markets bar was visual only |
| Stock rows | Mixed chrome; hardcoded slate hex |
| Watchlist fail | Silent → looked like empty |
| Stocks fail vs empty | Partially distinguished |
| Hardcoded `Color(0x…)` | markets_page **23**, stock_list_tile **3** |

## After

| Item | State |
|------|--------|
| Tabs | Core 4 always; F&O/ETF/Commodities/Currency **only if** matching instruments exist in browse results |
| Empty catalog tabs | Hidden (capability retained in `_selectedContent` cases 4–7) |
| Search | Same route; clearer empty vs error; tokens |
| Stock rows | Shared `StockListTile` with tokens + tabular figures + zero=neutral |
| Watchlist | Loading / failed+retry / empty |
| Stocks | Failed+empty → unavailable; success+empty → no instruments |
| Hardcoded hex | markets_page **0**, stock_list_tile **0** |

## Tabs behavior

Always: Watchlist · Indices · Stocks · Sectors  

Optional (count &gt; 0 in `_remoteSearchResults`):

- F&O — category keywords FUTURE/OPTION/DERIVATIVE/F&O  
- ETFs — category ETF or `*BEES`  
- Commodities — COMMODITY/MCX/METAL/ENERGY  
- Currency — CURRENCY/FOREX/FX  

Data models and API unchanged. Search remains EQUITY-oriented on the backend.

## Search

- Entry: Markets search affordance → `StockSearchPage`
- States: loading bar, degraded live-search banner, **AppErrorView** (network), **AppEmptyState** (no matches)
- Clear + refresh actions retained
- Result rows: logo, symbol, exchange, name, price, change (no provider/series)

## Stock row

`StockListTile`: logo · symbol · exchange · name · price · abs/% change · optional watchlist star.

## Indices / Movers

Unchanged data sources (props + `indexQuotes` + `widget.stocks`). Tokenized chrome. Movers remain under Indices (top 5 + View All). Home keeps a shorter movers summary.

## Stock detail routing

Unchanged: Markets / Search / Home → same `StockDetailPage` via `_openStock`. Buy/Sell on detail unchanged.

## Empty / Error

| State | UI |
|-------|-----|
| Watchlist empty | Empty + Search CTA |
| Watchlist failed | Error + Retry |
| Stocks failed | Unable to load / Retry |
| Stocks empty | No instruments |
| Search no matches | No matching stocks |
| Search failed | AppErrorView |
| Sectors none | Unavailable card |

## Responsive

Tab strip scrolls horizontally. Stock rows allow name ellipsis without crushing price. Narrow padding patterns retained.

## Tests

- `dart format` / `flutter analyze` / `flutter test`
- `flutter build web --dart-define=API_BASE_URL=http://localhost:3000` — LOCAL BUILD VALIDATION ONLY

## Hardcoded content TODO (later CMS)

Featured sparkline symbols (`HDFCBANK`…), index venue set — not redesigned this phase.
