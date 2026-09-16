# Profile UI / UX Upgrade (Phase 9)

Presentation polish of the Profile tab plus real biometric quick-login wiring. No KYC workflow, funds business rules, CMS loading, Deposit-on-Profile, or Nest support dual-entry changes.

## Before

1. Dark profile header with mixed `Colors.white` / `Colors.white70` / hex greens
2. Overview metrics strip (already tokenized)
3. Menu groups as `Card` + local `_accountTile` ListTiles
4. Sections: Account, Funds, Security, Preferences, Support & Education, Legal
5. **Logout nested inside Legal** card
6. No Profile biometric enable/disable control (API existed; login page only consumed it)
7. Legal pages used Theme text styles, full-bleed width
8. Scattered hardcoded fills/accents on bank details, wealth insights intro, language check

## After

1. Profile header tokenized (`AppColors.textInverse` / `AppColors.gain`, spacing/radius tokens)
2. Overview metrics unchanged (tokenized surface) — no Portfolio balance duplication beyond existing overview chips
3. Shared `ProfileSection` + `ProfileMenuRow` (`lib/widgets/profile_menu.dart`)
4. Same Phase 4 section groups and destinations
5. **Logout** moved to its own bottom destructive `ProfileMenuRow` (no chevron)
6. **Biometric quick login** row under Security when device supports it
7. Legal: `AppTypography`, ~680px reading width, secondary caption color
8. Light token swaps on bank / insights / language pages
9. Bank row copy clarified as withdrawal destination

---

## Sections

| Section | Rows |
|---------|------|
| Account | Personal Information → profile; KYC → kyc; Bank Accounts → banks |
| Funds | Loan Applications → LoanPage |
| Security | Change Password; Two-Factor; Transaction PIN; **Biometric quick login** (conditional) |
| Preferences | Alert Preferences; Appearance; Language |
| Support & Education | Help & Support (SaleSmartly chat panel); Wealth Insights |
| Legal | About Us; Terms; Privacy |
| (footer) | Logout (destructive); app name |

Deposit / Withdrawal remain on Home / Portfolio flows (not duplicated as Profile Funds rows). Balance-adjustment admin tools are not exposed.

---

## Account

- Header: name, phone, Account ID, KYC status pill, Client Tier / Status
- Personal Information → existing profile edit sheet
- No internal-only fields added

## KYC

- Profile shows status only: Verified / Pending / Required
- Opens existing KYC settings surface
- **No KYC workflow / approval logic changes**

## Bank

- Profile subtitle: “Linked bank account for withdrawals”
- Bank Details page already states withdrawals (not deposit account)
- Backend bank APIs unchanged

## Funds

- Profile Funds section: Loan Applications only
- Deposit / Withdrawal entry points remain outside Profile (existing Home/actions)
- No admin balance tools exposed

## Security

- Change Password → AccountSecurityPage
- Two-Factor → existing surface
- Transaction PIN → existing surface
- Biometric quick login (see below)

## Biometric status

| Item | Detail |
|------|--------|
| Capability | `DeviceBiometrics.available()` — null on web / unsupported → row hidden |
| Enabled | `AuthService.restoreBiometricToken()` non-empty |
| Enable | `LocalAuthentication.authenticate` then `enableBiometricQuickLogin` (signed-in) |
| Disable | `disableBiometricQuickLogin` |
| Label | “Biometric quick login”; subtitle Face ID or Fingerprint |
| Load | On Profile tab select (`selectedIndex == 4`) via `_loadBiometricSettings` |
| New APIs | **None** — uses existing AuthService + DeviceBiometrics |

## Alert Preferences

- Remains preference for which account updates the user receives
- Distinct from Inbox (message list / notifications tab)
- Existing toggles only — no fake preferences added

## Appearance

- Unchanged: Normal / High Contrast via existing `appearance_settings`
- No fake Dark Mode

## Language

- Existing en / hi options only (real supported locales)
- Selected check uses `AppColors.gain`

## Support

- Single user-facing Help & Support → SaleSmartly chat panel
- Nest/admin support console remains operational/admin-side (not dual-exposed on Profile)
- No architecture change this phase

## Learning Center / Insights

- Wealth Insights list: intro color tokenized
- Content still CMS-first with local fallbacks
- Marked for future Admin-managed content — no new hardcoded articles

## Legal

- Terms / Privacy / About: unified reading width, typography, spacing
- Updated date shown only when content provides it (existing)
- Future CMS — no backend change

## Logout

- Standalone destructive `ProfileMenuRow` below Legal
- Loss-colored icon/title; no chevron; no large red warning block
- Account deletion not added

---

## Hardcoded content classification

| Class | Examples |
|-------|----------|
| STATIC CLIENT UI | Section chrome, row icons, ProfileSection layout |
| USER DATA | Name, phone, Account ID, KYC status, tier |
| SERVER DATA | Profile snapshot, bank list, security flags |
| ADMIN-MANAGED CONTENT | Profile tile titles/subtitles (partial AppContent), About copy, Wealth Insights articles |
| LEGAL CONTENT | Terms / Privacy bodies (CMS-first + local fallback) |
| SUPPORT CONFIG | SaleSmartly entry (client); Nest support admin-side |
| APP CONFIG | Appearance modes, language codes, biometric capability |

### Admin-manageable candidates (do not implement CMS now)

| Item | Notes |
|------|-------|
| Profile section / tile titles & subtitles | Partially AppContent (`profile.section.*`, `profile.tile.*`); remaining English strings can move to CMS |
| Fallback legal Terms / Privacy bodies | Already CMS-first; local fallbacks remain for empty remote |
| About dialog copy | AppContent keys under `about.*` |
| Biometric / security help copy | Could be CMS FAQ snippets |
| Language labels | Currently hardcoded en/hi map on Language page |
| Wealth Insights articles | Already remote-capable; expand Super Admin editing later |

---

## Hardcoded UI colors (before → after)

| File / scope | Before | After |
|--------------|--------|-------|
| Profile header + status pill (`market_page.dart`) | `Colors.white` / `white70` / `white24` + `0xFF45D59A` / `0xff70e0ba` (~12 usages) | **0** (tokens: `textInverse`, `gain`) |
| Profile menu cards | Already on `AppColors.surface` | Unchanged via `ProfileSection` / `AppCard` |
| `legal_page.dart` | Theme-derived (no hex) | Token typography/colors; **0** hex |
| `bank_details_page.dart` | `0xFFF5F8FF` (**1**) | `AppColors.brandPrimarySoft` (**0**) |
| `account_content_page.dart` | `0xFF667085` (**1**) | `AppColors.textSecondary` (**0**) |
| `language_page.dart` | `Colors.green` (**1**) | `AppColors.gain` (**0**) |

Profile-region net: **~15 → 0** hardcoded color usages in the touched Profile/legal/light-token surfaces. Remaining `Color(0x…)` in `market_page.dart` are outside Profile (IPO banner, withdraw dialog, portfolio chrome).

---

## Responsive

- Profile header Wrap for status pills; long phone / name use Expanded columns
- Menu rows: compact ListTile, subtitle wraps; status + chevron trailing
- Legal: maxWidth 680 centered for web/tablet; padded ListView on phone
- Bank form: existing full-width fields

Targeted mentally for 320 / 360 / 412 / web; no emulator capture in this environment.

## Accessibility

- Status labels (Verified / Pending / Required) accompany color
- Logout not color-only (icon + “Logout” label + destructive style)
- ListTile `minTileHeight: 48` (≥44dp target)
- Biometric Switch has row title/subtitle for screen readers
- Contrast via Design System tokens (`textPrimary` / `textSecondary` / `gain` / `loss`)

---

## Tests

- `dart format --set-exit-if-changed lib test`
- `flutter analyze`
- `flutter test` (full suite + Profile/KYC/language/auth)
- `flutter build web --dart-define=API_BASE_URL=http://localhost:3000` — **LOCAL BUILD VALIDATION ONLY**

No emulator visual capture in this environment.
