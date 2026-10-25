# HNW Visual Acceptance Matrix

Every visual change must preserve the protected-flow contract and pass the state, viewport, language, accessibility, and failure checks below. Screenshots are evidence, not a substitute for behavior tests.

## Viewports

| Surface | Required sizes |
| --- | --- |
| Flutter phone | 320×640, 360×800, 390×844, 412×915 |
| Flutter alternate | landscape phone, keyboard visible, tablet |
| Customer Web/PWA | 768×1024, 1024×768, 1280×720, 1440×900, 1920×1080 |
| Admin | 1280×720, 1440×900, 1920×1080 |

## Pixel contract

- Use the semantic color, typography, spacing, radius, shadow, and motion tokens; the base rhythm is 8 px with 4 px only for compact internal alignment.
- Interactive controls are at least 44 logical pixels on customer surfaces and 44 CSS pixels in Admin; primary mobile form controls target 48 pixels.
- Focus is visible, status is never communicated by color alone, numeric values use tabular figures, and text contrast follows WCAG AA.
- Verify English and Hindi, text scale 1.0 and 1.4, reduced motion, long values, empty content, and narrow-width wrapping.
- Loading, submitting, pending, processing, success, rejected, error, empty, offline, stale, and unknown-result states use a title, explanation, truthful status, freshness when known, next step, and safe action.
- A financial timeout never reports success and never invites a blind retry. Existing data remains visible and is marked stale where safe.

## Evidence by journey

| Journey | Required evidence |
| --- | --- |
| Auth and recovery | phone/password/invite/support-code fields; keyboard; errors; 320 px; text 1.4; no SMS/email flow |
| KYC | six existing steps; upload failures; submitted/manual-review/result scene; reject note; no invented ETA |
| Markets and portfolio | loading/empty/error/offline/stale; quote freshness; long instrument names; tablet/Web |
| Trading | BUY/SELL, MARKET/LIMIT, DAY/IOC/FOK, confirmation, unknown result, same clientOrderId, no clipped field |
| Profile and support | every secondary page, sheet, dialog, SaleSmartly unavailable state, privacy-safe errors |
| Admin five roles | allowlisted navigation, tables, filters, pagination, details, confirmations, denied/error/empty, 1280–1920 px |

Intentional visual baseline updates require a short before/after note naming the reason and confirming that protected fields and actions did not change.
