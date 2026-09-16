# App Content Phase 12 — Super Admin Management UX

**Status:** Complete (Admin UX only).  
**Baseline before phase:** `7345055`  
**No Prisma schema changes.** Minimal API addition for Featured Instrument placement (blocking for Phase 12 UI).

---

## Navigation (ADMIN only)

```
APP 管理
├── /app-management     总览（真实计数）
├── /app-content        文案配置 (KV)
├── /insights           洞察文章
├── /announcements      平台公告
├── /featured-instruments 精选标的
├── /app-settings       客户端设置
└── /company-showcase   平台公司信息（既有模块，仅链接）

客服
└── /support-console    客服会话台（例外保留）
```

- Visible only to `UserRole.ADMIN` (no SUPER_ADMIN enum).
- BUSINESS / FINANCE / SUPPORT do not see APP 管理 entries.

---

## Content page (`/app-content`)

| Tab | Notes |
|-----|--------|
| Home | Banner / Funds / Market / News / Company / Profile / Withdraw / Legacy — Collapse, locale switch |
| Deposit | Clear warning: no platform bank / payment channel config |
| Support | Client content vs **INTERNAL SUPPORT DESK ONLY** |
| Trading & Portfolio | Presentation-only warnings; legacy key notes for Positions/Overview |
| Legal | Privacy/Terms; English available / Hindi not configured; preview; last updated |
| About | Marketing version ≠ build version; link to Company Showcase |
| Legacy Insights | Compatibility only; points to `/insights` for new articles |

---

## Insights / Announcements

- List / create / edit / publish / unpublish / delete (confirm)
- Preview drawers (content only, not Flutter UI)
- Announcement display status computed: Draft / Scheduled / Live / Expired

---

## App Settings

- ANDROID / IOS / WEB tabs via platform select
- Version format matches API DTO (`1.2.3` pattern)
- **Force Update** and **Maintenance Mode** require confirmation with before/after

---

## Featured Instruments

- Reuses `Instrument` via `GET /admin/market/instruments` (paginated + search)
- Toggles `featuredHome` / `featuredMarkets`, edits `displayOrder`
- **API unblock (non-Prisma):** `PATCH /admin/market/instruments/:id/placement` + list filters
- No second stock table; no quote/price edits

---

## Safety confirmations

| Action | Confirmation |
|--------|----------------|
| Insight delete (esp. published) | Modal |
| Announcement delete | Modal |
| Force Update on | Modal + before/after |
| Maintenance Mode on | Modal + before/after |

---

## RBAC

Unchanged: platform APP ops = `ADMIN` only. Audit remains on API layer.

---

## Preview principle

Content preview only (Drawer / floating card). No Flutter pixel recreation.

---

## Validation / Tests

| Check | Result |
|-------|--------|
| Admin lint | run in phase |
| Admin tsc | run in phase |
| Admin build | `NEXT_PUBLIC_API_URL=https://example.invalid` — LOCAL BUILD VALIDATION ONLY |
| Admin frontend unit tests | Existing Node harness only (`tests/**/*.test.mjs`); **no Vitest/Jest/RTL** — not introduced |
| API regression | ops-content + placement contract tests |

---

## Remaining Phase 13

- Flutter consume announcements / settings gates / featured lists
- Force-update & maintenance blocking UI
- Full dynamic Insights surfaces beyond smoke fallback

**Out of scope:** production migration, trading/KYC/funds/provider changes.

---

*End of Phase 12.*
