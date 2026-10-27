# Supply-chain follow-up design

## Scope

Fix the scheduled full-history secret-scan failure and strengthen repository-controlled supply-chain evidence. External providers, production credentials, market data and clearing connectivity remain out of scope.

## Decision

Use a reviewed `.gitleaksignore` containing only the exact fingerprints of synthetic findings already present in repository history. Do not ignore paths, rules, branches, or future line content. The scan remains fail-closed for any new or changed finding.

## Safety properties

- Every exception is tied to one historical commit, file, rule and line.
- A changed line has a different fingerprint and is not covered.
- The contract test rejects broad/path-only suppressions and verifies the full reviewed set.
- The workflow continues to scan complete history (`fetch-depth: 0`) and keeps its existing least-privilege permissions.

## Non-goals

No trading, registration, login, password recovery, funding, order semantics, customer-facing provider claims, or real external integrations are changed.
