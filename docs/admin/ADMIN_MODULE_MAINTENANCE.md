# Admin module maintenance

## Boundaries

- Five staff roles remain isolated: Super Admin, Manager, Finance, Business, and scoped Operations.
- `role-permissions.ts` maps routes to presentation permissions. API guards and scoped queries remain authoritative.
- `ops-page-registry.ts` records page owner, role, permission, API dependencies, and read-only status for migrated modules.
- `ops-action-registry.ts` records all migrated writes and their state, confirmation, idempotency, audit, and recovery requirements.
- `ops-mutation-contract.ts` provides consistent denied, conflict, rate-limit, timeout/unknown, and failed presentations.

## Change checklist

1. Register the page and action before adding a menu item or button.
2. Confirm the endpoint has server-side role and record-scope enforcement.
3. Use bounded server pagination; do not fetch all financial records.
4. Show loading, empty, denied, error, stale, and unknown-result states distinctly.
5. For a write, show current value, new value, customer impact, reason, request reference, and an explicit confirmation.
6. Do not optimistically report success. On 409 or timeout, refresh the record before another attempt.
7. Store an audit event without secrets, full credentials, authentication codes, or unnecessary PII.
8. Run Admin lint, tests, typecheck, production build, and the protected API contract gate.

## Ownership and incident routing

Customer/KYC belongs to Customer Operations; funding to Finance Operations; orders/trades to Trading Operations; personnel/2FA to Security Administration; content to Product Operations; health/deployment identity to Platform Operations. A UI failure must not be “fixed” by editing balances, orders, KYC status, or database records outside the audited service workflow.
