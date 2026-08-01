---
id: 2026-06-25-refine-dotty-cleanup-task-retirement
title: Add advisory cleanup retirement dates
state: ready-to-implement
createdAt: 2026-06-25T16:35:56.708Z
updatedAt: 2026-08-01T00:10:18.760Z
---

# Add advisory cleanup retirement dates

## Plan

## Objective

Let cleanup authors declare when a completed task should start prompting for source-repo retirement, without changing cleanup execution, claiming cross-machine completion, or mutating managed repos during `dotty update`.

## Verified current behavior

- Cleanup definitions live under each managed repo's `.dotty/cleanups/` directory.
- Directory-shaped tasks may define supported metadata in `.dotty/cleanups/<id>/config`; simple executable-file tasks have no metadata surface.
- Receipts live under `~/.dotty/cleanups/<repo>/<cleanup-id>/` and are keyed by repo name and cleanup id.
- Only `done` and `failed` affect runtime status. The absolute `source` path and `completed-at` timestamp are diagnostic metadata with no consumers.
- `dotty cleanups` lists applicable tasks as `pending`, `done`, or `failed`; `--pending` hides non-pending tasks and `--all` includes non-applicable tasks.
- Dotty has no shared ledger of every machine, environment, or downstream layer that may consume a cleanup.
- A client-side deletion during `dotty update` would only dirty each local managed checkout. It would not propagate retirement without a separate commit and push, and could interfere with later pulls.

## Design decision

Add one optional supported metadata field for directory-shaped tasks:

```bash
DOTTY_CLEANUP_RETIRE_AFTER="2026-09-01"
```

The value is an advisory UTC calendar date in strict `YYYY-MM-DD` form. A cleanup becomes retirement-due when the current UTC date is strictly later than the configured date. On the configured date itself, it is not yet due.

The field means: “After this date, prompt the maintainer to consider removing this task definition once it is locally complete.” It does not mean every possible machine ran the cleanup, and it does not disable or delete the task.

Do not infer retirement dates from cleanup ids, file timestamps, receipt `completed-at`, or a global default. Tasks without `DOTTY_CLEANUP_RETIRE_AFTER` retain their current behavior.

## Runtime behavior

Retirement metadata must not change execution:

- a pending applicable cleanup still runs during `install` or `update`, even after its retirement date;
- a failed cleanup still retries normally after its retirement date;
- a future or overdue retirement date is not exported to the cleanup script and does not change receipt state;
- Dotty never deletes, edits, commits, or pushes cleanup definitions automatically.

Invalid retirement metadata follows the existing invalid-config contract: Dotty reports the config error, does not execute that task, and `dotty doctor` fails for it. This keeps one config-validation path rather than treating the same file differently across commands.

## Status behavior

For an applicable task whose local receipt status is `done` and whose retirement date has passed, `dotty cleanups` renders:

```text
  retire  2026-remove-old-tool  Remove old tool state (after 2026-09-01)
```

All other statuses remain unchanged:

- overdue `pending` tasks remain `pending` so the next update still runs them;
- overdue `failed` tasks remain `failed` so the failure is not mistaken for retirement eligibility;
- future-dated completed tasks remain `done`;
- completed tasks without retirement metadata remain `done`;
- non-applicable tasks shown through `--all` remain `not applicable`.

`--pending` continues to show only `pending` tasks, so it excludes `retire` rows. Multiple retirement-due tasks across layered repos produce one footer after all repo groups:

> Retirement dates are advisory and completion is local. Remove retire-marked tasks from their repo when you accept that other machines may not have run them.

If no `retire` row is rendered, the footer is absent.

## Implementation scope

1. Extend cleanup config reset and allow-list handling with scalar `DOTTY_CLEANUP_RETIRE_AFTER`, defaulting to an empty string.
2. Add a focused Bash helper that validates a real `YYYY-MM-DD` calendar date, including month length and leap years, without GNU- or BSD-specific date parsing.
3. Compare valid dates lexicographically after obtaining the current UTC date once with `date -u '+%Y-%m-%d'`. Fixed-width ISO dates make chronological and lexical order equivalent under `LC_ALL=C`.
4. Keep `run_pending_cleanups()` behavior unchanged apart from shared validation of the new supported metadata.
5. In `cmd_cleanups()`, change only locally `done`, applicable, overdue rows to `retire`, append the configured date, and emit the advisory footer once when at least one such row was rendered.
6. Keep existing grouping, filters, exit behavior, and `No cleanup tasks found.` output unchanged.
7. Update the `cleanups` descriptions in `cmd_help()` and `completions/_dotty` to mention retirement guidance.
8. Update the command and one-shot cleanup sections of `README.md` with the field, UTC boundary, advisory semantics, directory-task requirement, example output, and explicit manual commit workflow.
9. Keep `.github/ISSUE_TEMPLATE/` and `examples/` unchanged unless implementation inspection finds an existing cleanup metadata example that must remain synchronized.

## Test contract

Add focused coverage in `test/cleanups.bats` for:

- a valid leap-day date is accepted and a non-calendar date is rejected by the shared config validation;
- a locally completed task with a past retirement date renders `retire` and its date;
- a completed task dated today or in the future remains `done`;
- an overdue pending task remains `pending` and still executes during `update`;
- an overdue failed task remains `failed`;
- completed tasks without the field remain `done`;
- `--pending` excludes `retire` rows;
- multiple overdue completed tasks across repos produce one advisory footer;
- non-applicable tasks remain `not applicable` under `--all`.

Use dates derived from the current UTC day for the boundary assertion and fixed distant past/future dates where exact-day behavior is irrelevant. Do not add a clock override or production-only testing knob.

## Explicit non-goals

- Do not automatically remove cleanup definitions during `install`, `update`, or status commands.
- Do not add a prune command, `--retirable` filter, aging window, owner field, target ledger, or shared receipt service.
- Do not skip pending or failed tasks after the retirement date.
- Do not retrofit existing tasks by parsing dates from their ids.
- Do not migrate, normalize, validate, or repair receipt `source` paths.
- Do not change receipt keys or completion semantics.
- Do not clean up empty task directories; normal Git retirement already removes tracked empty task directories, and `dotty doctor` diagnoses untracked residue.

## Acceptance criteria

- Directory cleanup configs accept an optional, valid `DOTTY_CLEANUP_RETIRE_AFTER` date and reject invalid calendar dates with a useful config error.
- Only locally completed, applicable tasks past that date render as `retire`.
- Date metadata never prevents a valid pending task from running merely because the date passed.
- Dotty performs no cleanup-definition mutation.
- Status output explains the local/advisory boundary exactly once when retirement-due rows are present.
- Help, zsh completions, README, implementation, and focused tests describe the same contract.
- Focused and full validation pass.

## Verification

- Run `bash -n dotty`.
- Run `./test/bats/bin/bats test/cleanups.bats` while iterating.
- Run `./test/bats/bin/bats test/` before completion.
- In a temporary two-repo chain, create past-, current-, future-, pending-, failed-, and non-applicable fixtures; verify rendered statuses, one advisory footer, and unchanged pending execution.
- Confirm the temporary managed repos remain clean after `dotty cleanups` and `dotty update`.

## Stopping points and exception criteria

- Stop and revisit the contract if implementation requires persistent retirement state, a clock override, GNU/BSD date branching, or source-repo mutation.
- If portable full calendar validation becomes materially larger than the feature, narrow validation to strict shape plus month/day ranges and document the remaining limit rather than importing a date dependency.
- Do not broaden the change into cross-machine inventory or repository automation. Upstream bots that commit or open retirement PRs are a separate adoption layer, not Dotty client behavior.

## Follow-up boundary

Existing cleanup tasks will not gain retirement dates automatically. Adding `DOTTY_CLEANUP_RETIRE_AFTER` to tasks in downstream dotfiles repos is separate owning-repo work after this Dotty behavior is implemented and released.

## Next honest step

Use `$jp:implement` or another explicit implementation request to implement the advisory retirement-date metadata, status rendering, validation, docs, and focused tests as one change.

## Agent handoff

The advisory retirement-date contract is approved, `ready-to-implement`, and persisted on `main`. It specifies optional `DOTTY_CLEANUP_RETIRE_AFTER="YYYY-MM-DD"` metadata, UTC advisory status rendering, unchanged pending/failed execution, no automatic repo mutation, portable calendar validation, synchronized docs/help/completions, and focused Bats coverage. No implementation has started. The next authorized workflow is `$jp:implement` or another explicit implementation request.
