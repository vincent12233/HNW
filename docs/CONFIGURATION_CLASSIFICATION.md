# Configuration Classification

Last updated: 2026-09-28

| Configuration | Owner | Secret | Client allowed | Delivery |
|---|---|---:|---:|---|
| `API_BASE_URL` | Flutter/Admin | No | Yes | build environment |
| `GOOGLE_CLIENT_ID` | Flutter | Public identifier | Yes | build environment |
| `SALESMARTLY_SCRIPT_URL` | Flutter/CMS | No | Yes | CMS or build environment |
| Error-report public endpoint/DSN | Client | Public identifier | Yes | build environment |
| Database credentials | API | Yes | No | server secret manager |
| JWT signing secret | API | Yes | No | server secret manager |
| Market provider secret | API | Yes | No | server secret manager |
| Object-storage secret key | API | Yes | No | server secret manager |
| KYC/virus-scan provider secret | API | Yes | No | server secret manager |
| Privileged webhook token | API | Yes | No | server secret manager |
| Android keystore/password | Release | Yes | No source/client runtime | CI secret store |
| iOS signing certificate/profile | Release | Yes | No source/client runtime | CI signing store |

## Rules

- Build-time substitution obscures nothing; anything shipped in a client is
  public to a determined user.
- Third-party calls requiring a secret are proxied by the API with authorization,
  validation, rate limiting, auditability, and timeout controls.
- `.env`, keystores, certificates, provisioning profiles, private keys, service
  account JSON, production backups, and token-bearing logs are never committed.
- Release builds require an approved public HTTPS API endpoint.
- Secret rotation must not require publishing a new mobile binary unless the
  value is explicitly classified as a public client identifier.
