# Supply-chain follow-up plan

1. Add a fingerprint-only Gitleaks exception file from the failed run's reviewed SARIF/history evidence.
2. Add a contract test that proves the exception file is exact and non-broad, while the workflow remains full-history and fail-closed.
3. Run the contract test, the local full-history Gitleaks scan, and the repository verification suite.
4. Inspect the complete diff for protected financial/authentication flows and secrets before opening a PR.
5. After review and merge, rerun the scheduled workflow and verify the repository state.
