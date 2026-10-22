# HNW Architecture Decisions

## D-001 — Keep the current production architecture

Decision: production remains Coolify plus Docker Compose with NestJS API,
five role-specific Admin processes, Flutter client, PostgreSQL, and Redis.

Reason: this is the documented and deployed repository architecture.

Evidence: `README.md`, `compose.production.yaml`,
`docs/小白部署与运维手册.md`, and `production-deploy.yml`.

Scope: production. Vercel and Supabase may be evaluated only as isolated
future development/preview resources; they are not production replacements.

## D-002 — Preserve Prisma 7 and the custom generated output

Decision: keep Prisma CLI, Client, and `@prisma/adapter-pg` at 7.10.0 at the
baseline, use the `prisma-client` generator, and generate into
`apps/api/src/generated/prisma`.

Reason: API imports the custom `client` and `enums` modules and the API service
uses `PrismaPg`.

Evidence: `apps/api/prisma/schema.prisma`, `apps/api/prisma.config.ts`,
`apps/api/src/prisma/prisma.service.ts`, and `apps/api/package-lock.json`.

## D-003 — Treat CI evidence as commit-specific

Decision: a test result is valid only when tied to the exact commit SHA and
recorded with command, exit code, environment, time, and evidence location.

Reason: `docs/STATUS.md` explicitly rejects using older results as evidence for
the current commit.

## D-004 — Keep production and disposable resources separate

Decision: migrations, seeds, and financial integration tests may use only
explicitly disposable PostgreSQL/Redis resources. Production URLs, secrets,
customer records, and deployment environments are outside development tests.

Evidence: `compose.local-test.yaml`, `compose.production.yaml`,
`scripts/verify-migration-upgrade.sh`, and `AGENTS.md`.

## D-005 — Current Phase 4A PR is review-only

As of the last live GitHub check, Draft PR #142 was open and unmerged. Its head
was `bed2c0a9294ddb55c53905f6ca74c9239cfefdbc` and its API CI, Docker CI, and
CodeQL runs were successful. Re-check GitHub before using this as current state.
