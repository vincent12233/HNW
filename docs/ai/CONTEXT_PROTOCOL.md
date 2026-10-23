# HNW Persistent Context Protocol

## Purpose and limits

This protocol preserves durable, auditable checkpoints across sessions. It
does not provide infinite context, perfect recall, or a substitute for source,
Git, or CI verification.

## Level 1 — minimum startup

Read, in order:

1. `AGENTS.md`
2. `docs/ai/CURRENT_STATE.md`
3. `docs/ai/SESSION_HANDOFF.md`

Then verify the active checkout with:

```sh
git status --short --branch
git rev-parse HEAD
git branch --show-current
```

Query GitHub for the current branch/PR/CI facts before relying on recorded
remote state.

## Level 2 — task context

Load only the files needed for the task:

- `PROJECT_OVERVIEW.md` for project boundaries and runtime versions
- `ARCHITECTURE.md` for data flow and module relationships
- `DECISIONS.md` for non-obvious constraints
- `TASK_QUEUE.md` for pending work and acceptance criteria
- exact source, workflow, schema, migration, or lockfile paths involved

Use incremental `rg`, exact file reads, and focused Git diffs. Do not load the
entire repository or all historical logs by default.

## Level 3 — deep verification

Expand into commit history, PRs, CI jobs, migration details, and dependency
metadata only when the task requires it. Record the exact SHA, URL, command,
exit code, environment, and timestamp for each material conclusion.

## Session start procedure

1. Read Level 1.
2. Verify local Git state and untracked files.
3. Verify current remote PR/CI state.
4. Identify whether the last task was complete, paused, or blocked.
5. Identify the allowed operation boundary.
6. Load Level 2 or Level 3 only as needed.

## Session end procedure

1. State completed work and exact files.
2. Record commit SHA if one exists; otherwise say uncommitted.
3. Record commands, exit codes, test counts, and CI URLs.
4. Record blockers, risks, and unknowns separately from facts.
5. Update `CURRENT_STATE.md` and `SESSION_HANDOFF.md` only when authorized.
6. Provide a copyable resume command.

## Integrity and conflict rules

- GitHub code, commit, PR, and CI facts override chat history.
- Never turn an unrun test into a passing result.
- Never describe an uncommitted change as completed or merged.
- Never overwrite untracked or unrelated changes.
- Preserve architecture decisions unless new evidence and explicit review change
  them.
- If local and remote state disagree, stop the dependent action and re-check.
- If a required write is not authorized, provide proposed content and report
  that it was not written.

## Security rules

Never store secrets, tokens, private keys, customer PII, production URLs with
credentials, database dumps, or unredacted operational logs in these files.
Use placeholders and cite the source path or public PR/CI URL instead.

## Compaction and refresh

After context compression, reload Level 1 from disk. Treat prior summaries as
orientation only until the current files and GitHub state are read again.
When a task crosses a major phase, refresh the relevant Level 2 documents and
write a new handoff checkpoint before stopping.
