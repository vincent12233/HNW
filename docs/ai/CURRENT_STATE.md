# HNW Current State

## 2026-11-27 security audit checkpoint

- Base commit `cbee77c2c2f20ae1c4f744a06a9a479aeb0a5069`.
- Updated effect to 3.22.1 for CVE-2026-121707, updated API image PAM packages for CVE-2025-6020, and clarified deposit operator scope in README.
- API lint/build and all 679 tests passed using isolated PostgreSQL 17 and Redis 7. Admin 154 tests, lint/typecheck, and 39 tooling tests passed.
- Findings and verification limits are recorded in `docs/AUDIT_2026-11-27.md`. Newly identified business defects remain open.
- Repository Trivy scan including development dependencies passed with zero fixable HIGH/CRITICAL findings.
- AOCI tooling is unavailable in this environment. Index synchronization and remote CI status require verification.

## Verified delivery baseline

Local production-hardening checkpoint on 2026-10-26:

- Default branch: `main`
- Production-hardening base commit: `6bad50399e30b604eae8f186937529cc23cafd5f`
- Active delivery branch: `codex/hnw-production-hardening-2026-10-26`
- Repository-controlled additions include fail-closed GitHub governance checks,
  supply-chain evidence, SHA-bound capacity/recovery evidence, responsive visual
  evidence, refresh-token replay protection, and a three-layer acceptance report.
- PR #146 delivered staff authenticator enrollment/reset controls, security
  hardening, and the scoped UI/UX upgrade.
- PR #147 consolidated the pending Admin/API dependency updates. Its PR checks
  and the applicable post-merge `main` workflows passed.
- PR #142 was closed as superseded after its `follow-redirects` 1.16.1 change
  was confirmed already present on `main`.
- The repository did not contain
  `.github/workflows/financial-runtime-verification.yml` at verification time.

The branch had not yet completed final PR/CI/merge verification when this
checkpoint was written. This is not a production-readiness claim. Re-read GitHub and Git before
using branch, PR, commit, or CI state in a later task.

## Preserved product boundaries

- Trading rules and execution semantics remain unchanged by the 2026-10-23
  security/UI delivery.
- Customer registration and login flows remain unchanged.
- Deposit methods and funding semantics remain unchanged.
- Staff Google Authenticator enrollment and role-scoped reset are administrative
  security controls, not changes to customer authentication.

## Operational cautions

- Production credentials, customer data, and deployment secrets must never be
  recorded in these context files.
- Branch protection, required checks, production reviewers, and deployment
  state are remote facts and require a fresh authorized read.
- Use `docs/STATUS.md` as the canonical delivery and operations queue; avoid
  duplicating volatile status in multiple documents.

## Recovery entry

1. Run `git status --short --branch`, `git rev-parse HEAD`, and
   `git branch --show-current`.
2. Fetch/prune and compare the checkout with `origin/main` without discarding
   local changes.
3. Query current PRs and workflows for the exact head SHA.
4. Read `SESSION_HANDOFF.md`, then load only task-specific source and evidence.


## 2026-11-27 六项审计修复交付检查点

本轮修复以 #191 head `8a347bfd68579a65adf84b617188c83fc1b6ffc4` 为基线，
分支 `codex/fix-six-audit-findings-20261127`。完整实现、三个迁移、客户端契约、
验证命令及部署权限限制见 `docs/AUDIT_FIX_DELIVERY_2026-11-27.md`。
本地 API 700、后台 155、Flutter 503、脚本 50 项通过；Flutter 45 项既有条件跳过。
空库与基线带数据升级通过。不得沿用 #191 CI 作为本轮证明，恢复任务时按最终 head 查询。
生产合并、发布、回滚、数据迁移均未授权、未执行。实际 Coolify 配置读取 403，
不可变目标部署适配器与真实测试环境验收仍待权限；缺少能力时流程失败关闭。
AOCI 服务当前不可用，同步与 27 项中危依赖及外部联调按用户边界单独跟踪。
