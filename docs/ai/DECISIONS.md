# HNW Architecture Decisions

## D-001 - Keep the current production architecture

Decision: production remains Coolify plus Docker Compose with the NestJS API,
five role-specific Admin processes, Flutter client, PostgreSQL, and Redis.

Reason: this is the documented repository architecture.

Evidence: `README.md`, `compose.production.yaml`,
`docs/小白部署与运维手册.md`, and
`.github/workflows/production-deploy.yml`.

Scope: Vercel and Supabase may be evaluated only as isolated future
development/preview resources; they are not production replacements.

## D-002 - Preserve Prisma 7 and custom generated output

Decision: keep Prisma CLI, Client, and `@prisma/adapter-pg` on the repository's
reviewed Prisma 7 line, use the `prisma-client` generator, and generate into
`apps/api/src/generated/prisma`. The verified 2026-10-23 baseline is 7.10.1.

Reason: the API imports the custom `client` and `enums` modules and uses
`PrismaPg`.

Evidence: `apps/api/package.json`, `apps/api/prisma/schema.prisma`,
`apps/api/prisma.config.ts`, and `apps/api/src/prisma/prisma.service.ts`.

## D-003 - Treat CI evidence as commit-specific

Decision: a test result is valid only for its exact commit SHA and environment.
Record the command or workflow URL, result, and relevant timestamp before using
it as release evidence.

Reason: dependency, workflow, source, and environment changes can invalidate
older results.

## D-004 - Keep production and disposable resources separate

Decision: migrations, seeds, and financial integration tests may use only
explicitly disposable PostgreSQL/Redis resources. Production URLs, secrets,
customer records, and deployment environments are outside development tests.

Evidence: `compose.local-test.yaml`, `compose.production.yaml`,
`scripts/verify-migration-upgrade.sh`, and `AGENTS.md`.

## D-005 - Preserve core product behavior during UI/security work

Decision: UI/UX and administrative security improvements must not silently
change trading rules, customer registration/login, or deposit methods.

Reason: these are explicit owner constraints and high-risk financial behavior.
Any intentional change requires separate scope, tests, review, and release
evidence.
