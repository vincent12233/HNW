# Security Policy

## Supported versions

Security fixes are applied to the latest commit on the `main` branch. Older
commits, forks, and unpublished builds are not supported.

## Reporting a vulnerability

Please use GitHub's private vulnerability reporting feature for this
repository. Do not open a public issue or pull request containing exploit
details, credentials, personal data, or other sensitive information.

Include the affected component, reproduction steps, expected impact, and any
suggested mitigation. Reports will be acknowledged as soon as practical and
coordinated disclosure will be used when a vulnerability is confirmed.

If private vulnerability reporting is unavailable, contact the repository
owner through their GitHub profile without including sensitive technical
details in the initial message.

## Supply-chain evidence

Every pull request and `main` build runs the Supply Chain Security workflow.
It generates CycloneDX SBOM files for the API and Admin applications, scans
the Git history for secrets, and scans the production API container for HIGH
and CRITICAL vulnerabilities. Evidence is named with the exact commit SHA and
retained for 90 days.

HIGH or CRITICAL findings fail the workflow. A suspected false positive must
be reviewed and documented through the normal pull-request process; do not
silence findings by weakening the repository-wide severity threshold or by
committing credentials to an allowlist.
