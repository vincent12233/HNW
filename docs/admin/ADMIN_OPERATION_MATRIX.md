# Admin operation matrix

The server remains the authorization boundary. The Admin action registry controls presentation and recovery only; it never grants an endpoint permission.

| Module | Action | Roles | Eligible state | Required controls | Recovery |
| --- | --- | --- | --- | --- | --- |
| KYC | Approve / reject | Business, Manager | Pending | reason, impact, confirmation, request ID, audit | Refresh submission after 409, timeout, or unknown result |
| Deposits | Confirm manual credit | Super Admin, Finance, scoped Operations | Pending | deposit order id, reason, confirmation, ledger audit | Reload deposit and ledger; never credit twice |
| Withdrawals | Approve / reject | Super Admin, Finance | Pending | order id, reason, confirmation, audit | Reload request, freeze, and ledger |
| Staff security | Reset authenticator | Super Admin for administrators; Manager only for scoped staff | Active | attestation, reason, confirmation, audit | Verify current setup and audit before another reset |
| Orders | View | Existing role scope | Any existing order state | read-only, server pagination | Refresh; no Admin cancellation capability is introduced |
| Trades | View | Existing role scope | Existing settled data | read-only, server pagination | Refresh; no edit/delete capability |
| System | Health, governance, deployment identity | Super Admin | N/A | `audit.read`, read-only | Missing evidence is Unavailable; use operational runbook |

Every new mutation must be added to `apps/admin/lib/ops-action-registry.ts` with eligible states, roles, reason and confirmation requirements, idempotency identity, audit event, and unknown-result recovery. CI rejects incomplete registrations.
