# SaleSmartly customer-support migration

## Ownership boundary

SaleSmartly owns customer chat, agent assignment, collaboration, tags and chat history. HNW continues to own authentication, password-reset-code issuance, manual-deposit records, balances, orders, KYC, staff permissions and audit logs.

The standalone HNW chat console has been removed from Admin navigation and source. Existing `support_conversations` and `support_messages` records remain in the database as a read-only retention archive; this migration does not delete them. The legacy chat controller, gateway and service remain dormant only as rollback source until retention and export acceptance are signed off. They must not be re-enabled without security review.

## Verified vendor capabilities and deliberate limits

Verification date: 2026-10-25.

- The official [SaleSmartly JSSDK documentation](https://help.salesmartly.com/docs/salesmartly-chat-plugin-jssdk-developer-documentation) documents `setLoginInfo`, `clearUser`, `chatOpen`, `chatClose`, unread events and command status callbacks. HNW uses these capabilities on Web/PWA and clears vendor identity during logout.
- The official [SDK demo catalogue](https://help.salesmartly.com/docs/SaleSmartly-SDK-Demo) identifies separate Web, Android and iOS SDK paths. HNW keeps platform-specific bridges and a controlled unavailable/retry state.
- The official [API availability documentation](https://help.salesmartly.com/docs/api-use) states that API access requires a Max-or-higher plan and assisted integration. No subscription entitlement or project API token is committed to this repository, so server-side API automation is disabled.
- The official [API header/signature guide](https://help.salesmartly.com/docs/obtain-instructions-for-the-header-parameter-of-api/open) describes API request signing but does not establish an inbound HNW Webhook signature contract for this project. HNW therefore does not accept SaleSmartly Webhooks yet.

Do not enable API or Webhook processing until the account owner supplies plan entitlement, official endpoint/event schemas, signature and timestamp rules, replay semantics, test credentials, privacy terms and data-location confirmation. Secrets belong in the deployment secret store, never source control or customer-configurable content.

## Data minimisation

The client derives a stable one-way customer reference from the internal user ID and sends only:

- `customerReference`: `hnw_` plus a truncated SHA-256 digest;
- `displayName`: a generic HNW customer label derived from the digest;
- platform label (`web`, `android` or `ios`);
- a user-selected support-topic preset.

The integration must not send access/refresh tokens, phone, legal name, email, account IDs/numbers, password or reset code, TOTP, PAN/Aadhaar data or evidence, bank details, balances, KYC files, complete orders, internal roles, logs, stack traces or request bodies.

HNW stores only a staff-entered SaleSmartly interaction reference when a verified support interaction leads to a password-reset action. The record contains provider, external reference, purpose, recovery-session reference, actor, status and timestamps. It contains no message body or chat history.

## Password recovery and manual deposit

The customer-facing buttons and business flows remain unchanged:

1. The customer starts the existing HNW recovery or deposit-support flow.
2. Customer communication opens in SaleSmartly.
3. Staff independently verifies identity or payment evidence according to the existing operations policy.
4. For password recovery, authorised staff open **固定邀请码客户 → 密码找回安全操作**, select the HNW recovery request, enter the SaleSmartly interaction reference, attest independent verification and issue a single-use code. The code is shown once and remains governed by HNW expiry, attempt and one-use controls.
5. For deposits, staff continue using the existing HNW deposit/finance workflow. SaleSmartly cannot credit balances or mutate transactions.

SaleSmartly must never call password, balance, order, KYC or permission mutation endpoints directly.

## Failure and incident handling

- SDK load/open timeout: show the safe unavailable state and Retry; never claim that an agent is connected.
- Logout: clear SaleSmartly identity on a best-effort basis, but never block local logout if the vendor is unavailable.
- Vendor outage: continue showing account and transaction history; direct users to retry support later. Do not create an internal shadow-chat write path.
- Duplicate recovery action: HNW row locking and active-code checks prevent issuing another valid code while one is active; duplicate external references are unique per purpose.
- Suspected identity mismatch: do not issue a code or credit funds. Record the incident in the HNW audit workflow.
- Privacy request: locate SaleSmartly history using the pseudonymous reference and follow the contracted export/deletion process; retain HNW financial/security records according to legal policy.

## Rollout and exit gates

Before production enablement, verify Web/PWA, Android and iOS with a real SaleSmartly project; login identity linking; logout clearing; upload permissions; unavailable/retry states; no raw PII in vendor profiles; account recovery; manual deposit; and audit visibility. Export a sample conversation and confirm the contracted retention/deletion process.

If SaleSmartly must be replaced, disable the script URL, export vendor history under the contract, preserve HNW interaction-reference and audit records, rotate/remove vendor secrets, and connect the replacement through the same minimised platform interface. Do not restore the removed internal chat console as a shortcut.
