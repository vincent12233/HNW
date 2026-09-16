# APP Navigation Cleanup (Phase 4)

Information-architecture cleanup only. No trading, KYC, funds, or market-provider logic changes.

## Navigation map (after)

```
AuthGate
├── SplashPage
├── LoginPage → ForgotPasswordPage | RegisterPage | KycUploadPage
└── MarketHomePage (5 tabs)
    ├── Home → Search, Notifications (inbox), Deposit, Withdraw, StockDetail, MarketNews
    ├── Markets → Search, Notifications, StockDetail (tabs unchanged)
    ├── Trade → modules + StockDetail (9 modules unchanged)
    ├── Portfolio → ProductPortfolioPage (Institutional · OTC · IPO)
    └── Profile → grouped secondary pages (below)
```

### Profile groups

| Group | Items |
|-------|--------|
| Account | Personal Information, KYC Verification, Bank Accounts |
| Funds | Loan Applications |
| Security | Change Password, Two-Factor Authentication, Transaction PIN |
| Preferences | Alert Preferences, Appearance, Language |
| Support & Education | Help & Support, Wealth Insights |
| Legal | About Us, Terms & Conditions, Privacy Policy, Logout |

Deposit / Withdraw remain on Home quick actions (not duplicated into Profile this phase).

---

## Decisions

### Appearance + Language → Preferences hub?

**Decision: KEEP flat under Preferences section (no extra hub page).**

Reason: Theme/Appearance and Language were already listed under a Preferences group. Adding Profile → Preferences → Appearance would add a click without reducing clutter. Appearance and Language remain separate pages (different settings logic).

### Notification naming

| Before | After | Role |
|--------|-------|------|
| Bell → “Notifications” | Unchanged | Inbox |
| “Notification Settings” | **Alert Preferences** | Toggle prefs |
| Settings gear → preferences | **Removed** (duplicate of Alert Preferences) | — |
| AccountSettings title “Preferences” | **Alert Preferences** | Matches tile |

### Holdings vs Portfolio

| Surface | Before | After |
|---------|--------|-------|
| Bottom nav | Portfolio | Portfolio (unchanged) |
| Portfolio page | Title only | Title + subtitle “Institutional · OTC · IPO” |
| Profile metric | Total Portfolio | **Product Holdings** |
| Trade module/shortcut | Holdings | **Positions** (equity trading positions) |

No data-source merge. Models and APIs unchanged.

### Markets empty tabs (F&O / ETFs / Commodities / Currency)

**Decision: KEEP all tabs visible. Defer hide-when-empty to Phase 6.**

Reason: Empty state today is based on keyword filter over the current stock search/catalog slice, not a reliable “category permanently unavailable” signal. Hiding tabs from that signal could incorrectly remove future catalog categories.

### Trade 9 modules

**Decision: NO structural change.** Recorded for Phase 7.

### Reconciliation section

**Decision: KEEP unreachable.** Still no product decision to expose `AccountSettingsPage('reconciliation')`. Not deleted (API + code remain).

---

## Change log

| Item | Old location | Decision | New location | Dependency check | Reason |
|------|--------------|----------|--------------|------------------|--------|
| Settings gear | Profile header | REMOVE duplicate entry | Alert Preferences tile only | Same destination kept | Duplicate of notification prefs |
| Notification Settings label | Profile → Preferences | RENAME | Alert Preferences | Same page/API | Distinguish from inbox |
| Preferences AppBar | AccountSettings | RENAME | Alert Preferences | Same section | Align with tile |
| Theme label | Profile | RENAME | Appearance | Same AppearancePage | Match page purpose |
| Profile groups | Flat Account & Security + Support & More | REGROUP | Account / Funds / Security / Preferences / Support & Education / Legal | All destinations kept | Reduce cognitive load |
| Terms / Privacy | Support & More | MOVE group | Legal | Pages kept | Clearer IA; not deleted |
| Total Portfolio metric label | Profile overview | RENAME | Product Holdings | Same calculation | Reduce Holdings/Portfolio confusion |
| Trade Holdings label | Trade shortcuts/modules | RENAME | Positions | Same module index 2 | Clarify vs Portfolio tab |
| Portfolio subtitle | — | ADD | Under Portfolio title | CMS key optional | Clarify product scope |
| Bottom nav chrome | Hardcoded white/border | TOKENIZE | AppColors / AppSpacing | Theme only | Design system |
| F&O/ETF/… tabs | Markets | KEEP | Unchanged | — | Unreliable empty signal → Phase 6 |
| Trade tab IA | 9 modules | KEEP | Unchanged | — | Phase 7 |
| Reconciliation | Dead section | KEEP | Unreachable | API exists | No product decision |

### Removed items

- Profile header Settings gear only (duplicate navigation entry). **No pages deleted.**

### Pages deleted

**None.**

---

## Main tabs (unchanged architecture)

Home · Markets · Trade · Portfolio · Profile

Selected state uses design-system `AppColors.navSelected` / `navHeight` 68.
