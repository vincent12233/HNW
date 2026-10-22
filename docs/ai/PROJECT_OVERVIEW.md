# HNW Project Overview

## Verified identity

- Repository: `vincent12233/HNW`
- Baseline inspected for this context set: `7f5e5f28171e086d85b8b3f40378a9b2545abcb6`
- Default branch: `main`
- Local development branch at inspection: `work`
- Node.js: `.nvmrc` specifies 24

## Product shape

HNW is an India-focused trading platform with a customer Flutter app, a
NestJS API, and five role-specific operations frontends backed by one Admin
Next.js application. The API covers registration, KYC, accounts, funding,
withdrawals, trading, support, and operations management.

## Repository map

| Path | Responsibility |
| --- | --- |
| `apps/api` | NestJS API, Prisma client, migrations, financial and operational services |
| `apps/admin` | Next.js operations UI for admin, manager, finance, business, and support roles |
| `apps/client` | Flutter customer application |
| `apps/api/prisma` | Prisma schema and versioned PostgreSQL migrations |
| `.github/workflows` | API, Admin, Flutter, Docker, CodeQL, readiness, recovery, and deployment checks |
| `compose.local-test.yaml` | Isolated local API/Admin/PostgreSQL/Redis E2E stack |
| `compose.production.yaml` | Coolify production application template |
| `scripts` | Verification, migration, recovery, smoke, and operational tooling |
| `docs` | Operational, architecture, release, and acceptance documentation |

## Runtime baseline

- Prisma CLI, Client, and PostgreSQL adapter: 7.10.0 at the inspected baseline
- Prisma generator: `prisma-client`
- Generated output: `apps/api/src/generated/prisma`
- Database: PostgreSQL 17
- Redis: Redis 7
- Production architecture: Coolify plus Docker Compose

Sources: `README.md`, `.nvmrc`, `apps/api/package.json`,
`apps/admin/package.json`, `apps/api/prisma/schema.prisma`,
`compose.local-test.yaml`, and `compose.production.yaml`.
