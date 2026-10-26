# Client Screen Inventory

The machine-readable registry is `scripts/client-screen-inventory.json`; `node scripts/check-client-screen-inventory.mjs` fails when a Flutter page or page fragment is added or removed without updating the registry.

Each registered surface must be assigned during implementation to a journey tier, entry point, prerequisites, supported platforms, protected-flow status, state matrix, and visual evidence. All 70 current files under `apps/client/lib/pages` are registered. A file entry is coverage ownership, not proof that every state is already implemented.

## Coverage tiers

1. Protected: registration, login, recovery, deposit, KYC, order entry and confirmation.
2. Primary: Home, Markets, Trade, Portfolio, Profile.
3. Secondary: search, indices, movers, news, notifications, withdrawal, loan, settings, security, bank, language, appearance, legal and content.
4. Overlay/fragment: drawers, sheets, dialogs, camera, status and page sections.

Required states are loading, empty, error, offline, stale, and success, plus submitting/pending/rejected/unknown-result wherever an operation exists.
