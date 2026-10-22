# HNW Architecture

## Runtime topology

```text
Flutter customer app
        |
        v
NestJS API  ---> PostgreSQL 17
        |
        +------> Redis 7 for shared rate limiting
        |
        +------> private object storage and configured external providers

Next.js Admin application (five role processes/ports) ---> NestJS API
```

Production uses `compose.production.yaml` in Coolify. PostgreSQL, Redis,
private object storage, scanning, market, and other provider endpoints are
supplied through deployment environment variables. The repository does not
contain production credentials.

## API data path

The API reads `DATABASE_URL` through `ConfigService`, constructs `PrismaPg`
from `@prisma/adapter-pg`, and extends the generated Prisma `PrismaClient`.
Prisma configuration is in `apps/api/prisma.config.ts`; versioned migrations
are under `apps/api/prisma/migrations` and are deployed with
`prisma migrate deploy`.

Application imports use the custom generated modules:

- `apps/api/src/generated/prisma/client`
- `apps/api/src/generated/prisma/enums`

## Isolated development path

`compose.local-test.yaml` provides PostgreSQL 17, Redis 7, the API, five
role-specific Admin services, and private-object volumes. Database and Redis
ports bind to loopback by default. The stack uses `hnw_e2e` and test-only
credentials and must not be used as a production deployment template.

## Quality path

- API CI: install, audit, Prisma generation, fresh migration, upgrade
  verification, lint, build, smoke checks, Jest, and coverage gates.
- Admin CI: install, production dependency audit, lint, tests, typecheck, and
  build.
- Flutter CI: locked dependency installation, architecture checks, analysis,
  and tests.
- Docker CI: API/Admin image builds, Compose validation, and non-root checks.
- CodeQL: JavaScript/TypeScript analysis and SARIF artifact upload.
- Production deployment: manual dispatch, `main` check, exact SHA confirmation,
  `production` environment, Coolify webhook, and post-deploy smoke.
