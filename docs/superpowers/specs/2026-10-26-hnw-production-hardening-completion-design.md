# HNW Production Hardening Completion Design

Date: 2026-10-26

## Intent

Complete every production-hardening item that can be implemented and verified inside the HNW repository without pretending that external providers, regulated-market integrations, production credentials, legal approvals, physical devices, or live infrastructure already exist.

## Protected product contracts

- Customer registration remains India phone number, password, and invite code.
- Customer login remains phone number and password.
- Password recovery remains a SaleSmartly-assisted recovery-code flow.
- Deposits remain customer-service initiated and finance-reviewed manual credits.
- Existing BUY/SELL, MARKET/LIMIT, DAY/IOC/FOK, freeze, matching, cancellation, and settlement semantics do not change.
- The trade screen keeps every existing order field and confirmation step.
- Staff login remains employee ID, password, and Google Authenticator with the existing reset hierarchy.
- Customer surfaces must not expose repository, environment, infrastructure, provider-secret, or internal-role details.

## Completion boundary

Repository-controlled completion means code, tests, workflows, deployment templates, evidence formats, and operating instructions are present and validated for the exact commit. External completion is intentionally not claimed for licensed market data, KYC identity providers, exchange/clearing connectivity, production DNS/TLS/WAF, production secrets, app-store signing, legal entity text, or physical-device evidence.

## Approach

Use incremental hardening of the existing Flutter + NestJS + Next.js modular monolith. Do not introduce a microservice rewrite or new trading products. Add enforceable controls and executable evidence around the existing system: governance verification, supply-chain controls, release provenance, load/failure drills, recovery evidence, visual contracts, and operational documentation.

## Deliverables

1. A repository audit command that fails closed when production governance, required checks, security scanning, or environment protection is missing.
2. CI supply-chain checks for SBOM generation, secret scanning, dependency review, container vulnerability scanning, and immutable artifacts.
3. Repeatable capacity and failure-injection scenarios for public health, authenticated API boundaries, Redis degradation, outbox backlog, and idempotent financial commands, with machine-readable reports.
4. Recovery-drill evidence that validates restore integrity and reconciliation, without accessing production by default.
5. Visual-contract coverage for critical Flutter states and responsive Admin/PWA routes, including screenshot artifacts in CI.
6. Session-security verification for disable, logout, password change, authenticator reset, refresh replay, and multi-device boundaries without changing login credentials.
7. A production acceptance command and evidence manifest tied to one Git SHA.
8. Updated status, runbooks, and handoff records that distinguish automated proof from environment-backed evidence.

## Non-goals

- No KYC vendor, market-data vendor, exchange, clearing, payment gateway, SMS OTP, crypto, GTT, basket, F&O, copy trading, or automated strategy integration.
- No claim of production readiness based only on templates or simulated output.
- No direct production deployment or migration.
- No changes to protected customer or trading flows.

## Acceptance

- All affected local lint, type, unit, integration, build, release, and configuration checks pass.
- New controls have tests that fail before implementation and pass afterward.
- Full repository verification passes from the isolated worktree.
- No secret, generated build output, or unrelated change is committed.
- A pull request is created, all required remote checks pass, and repository governance is verified from GitHub rather than inferred from YAML.

