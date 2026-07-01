---
id: 2026-06-24-design-dotty-one-shot-cleanup-tasks
title: Design dotty one-shot cleanup tasks
state: complete
createdAt: 2026-06-24T23:37:29.430Z
updatedAt: 2026-06-25T00:19:11.428Z
---

# Design dotty one-shot cleanup tasks

## Plan

# Dotty one-shot cleanup tasks

## Problem
Dotfiles hooks sometimes need temporary cleanup logic when a tool is removed, renamed, or backed out. Today those routines get embedded in `.dotty/run.sh`, run forever on every `dotty install` / `dotty update`, and rely on a TODO plus memory to remove them later.

Current examples that motivated this plan:

- `cleanup_legacy_gsd_core` in the base dotfiles hook removes old GSD Core files and has a TODO to remove after propagation.
- A private overlay's cleanup helpers remove legacy tmux-agent-bar state and stale Codex plugin wrapper outputs from `.dotty/run.sh`.

## Goal
Add a first-class Dotty cleanup-task surface that lets repos ship one-shot cleanup or migration scripts outside the permanent hook. Dotty should run applicable tasks automatically during `install` and `update`, record local completion, skip completed tasks, and expose status so stale cleanup files are easier to retire.

## Non-goals
- Do not hardcode personal machine names, repo names, or paths in Dotty.
- Do not auto-edit or auto-commit dotfiles repos when a cleanup completes.
- Do not create a cross-machine shared completion ledger in the first implementation. Local completion is reliable; cross-machine aggregation needs an explicit transport and should not be implied.
- Do not replace `.dotty/run.sh`; hooks remain the permanent setup surface.

## Proposed interface
Add repo-defined cleanup tasks under `.dotty/cleanups/`.

A cleanup task is either:

- `.dotty/cleanups/<id>`: executable script for the simple case.
- `.dotty/cleanups/<id>/run.sh`: executable script with optional `.dotty/cleanups/<id>/config` for metadata.

The task id is the filename or directory name. Keep ids stable and descriptive, such as `2026-06-remove-gsd-core`.

Optional task config is Bash sourced by Dotty, matching the existing trust model for `.dotty/config`:

```bash
DOTTY_CLEANUP_ENVIRONMENTS=(laptop remote)
DOTTY_CLEANUP_MACHINES=(work-laptop personal-laptop)
DOTTY_CLEANUP_DESCRIPTION="Remove legacy GSD Core Codex files"
```

`DOTTY_CLEANUP_MACHINES` is matched against an optional local machine id. Dotty should read the current machine id from `DOTTY_MACHINE_ID`, falling back to `$DOTTY_DIR/machine-id` when present. If neither exists, machine filtering is unavailable and machine-scoped tasks should be treated as not applicable with a warning in verbose/status output.

## Runtime behavior
During `dotty install` and `dotty update`, for each repo in chain order:

1. Pull if needed.
2. Link `home/` and environment overlays, including existing orphan-symlink cleanup.
3. Run pending applicable cleanup tasks for that repo.
4. Run the repo hook.

Run cleanup tasks after linking so task scripts can rely on current managed files, and before hooks so old generated state can be removed before permanent setup recreates current state.

Dotty exports this context to cleanup scripts:

- `DOTTY_REPO_DIR`
- `DOTTY_ENV`
- `DOTTY_COMMAND` (`install` or `update`)
- `DOTTY_VERBOSE`
- `DOTTY_DRY_RUN`
- `DOTTY_LIB`
- `DOTTY_CLEANUP_ID`
- `DOTTY_CLEANUP_STATE_DIR`
- `DOTTY_MACHINE_ID` when known

Completion is recorded only after the cleanup exits zero. Failed cleanups are non-fatal like hooks: Dotty warns, keeps processing later repos/tasks, includes failures in the final summary, and does not mark the task complete.

Dry-run should not execute cleanup scripts. It should report which pending cleanups would run.

## State model
Store local completion under `$DOTTY_DIR/cleanups/`:

```text
$DOTTY_DIR/cleanups/<repo-name>/<cleanup-id>/done
$DOTTY_DIR/cleanups/<repo-name>/<cleanup-id>/source
$DOTTY_DIR/cleanups/<repo-name>/<cleanup-id>/completed-at
```

The initial implementation should key completion by repo name and cleanup id, not by file content hash. If a cleanup must run again, add a new id. This keeps destructive cleanup behavior explicit and avoids surprise reruns from comment-only edits.

## Status command
Add a read-only command:

```bash
dotty cleanups
```

Default output should resolve the active chain and show applicable cleanups for the current machine/environment grouped by repo:

- `pending`
- `done`
- `failed` only if there is local failure state, if implemented
- `not applicable` only in verbose mode or with `--all`

Suggested options:

- `dotty cleanups --all`: include non-applicable cleanup tasks and completed tasks.
- `dotty cleanups --pending`: show only pending applicable tasks.

Keep the first version local-machine scoped. If a cleanup declares target machines, status can display the target list and current machine id, but it should not claim that other machines completed unless Dotty has a real shared receipt mechanism later.

## Doctor checks
Extend `dotty doctor` to validate cleanup definitions:

- `.dotty/cleanups` is a directory when present.
- each cleanup id is a file or directory, not a broken symlink.
- simple file tasks are executable.
- directory tasks have an executable `run.sh`.
- optional `config` loads cleanly and only uses supported metadata variables.

## Docs and completions
Update the same user-facing surfaces as other Dotty behavior changes:

- `cmd_help()` in `dotty`
- `completions/_dotty`
- `README.md`
- `AGENTS.md` project map if the new directory becomes part of the public repo contract
- relevant tests under `test/`

Docs should show moving a temporary `.dotty/run.sh` cleanup into `.dotty/cleanups/<id>/run.sh`, and should explicitly say local completion is not a cross-machine shared receipt.

## Test plan
Add focused Bats coverage for:

- cleanup scripts run during `install` and `update`.
- cleanup scripts do not run during `link`.
- successful cleanup is marked done and skipped on the next update.
- failed cleanup is not marked done and appears in the final warning summary.
- dry-run reports pending cleanups without executing them or writing state.
- environment filters include/exclude tasks correctly.
- machine filters include/exclude tasks when a machine id is configured.
- `dotty cleanups` lists pending and completed tasks from the resolved chain.
- later repos do not override earlier cleanup tasks; cleanups are per-repo state, unlike repo-defined commands.
- `doctor` reports malformed cleanup definitions.

## Implementation slices

1. Add cleanup discovery helpers and local state helpers in `dotty`.
2. Add cleanup execution into `process_repo` after linking and before hooks.
3. Add `cmd_cleanups` for read-only status.
4. Extend `doctor` for cleanup validation.
5. Update help, completions, README, and AGENTS.
6. Add Bats tests, starting with execution/state behavior before status/doctor polish.
7. Migrate `cleanup_legacy_gsd_core` from the base dotfiles hook into a real cleanup task as a downstream validation once the Dotty feature lands.

## Agent handoff

Implemented and verified Dotty one-shot cleanup tasks. The feature discovers .dotty/cleanups tasks, supports executable-file and directory/run.sh shapes, optional Bash metadata for environment/machine/description, install/update execution after linking and before hooks, dry-run reporting without execution or state writes, local done/failed receipts under $DOTTY_DIR/cleanups/<repo>/<id>, dotty cleanups status, doctor validation, zsh completions, README, AGENTS, and focused Bats tests. Verification passed: ./test/bats/bin/bats test/cleanups.bats, targeted adjacent suites, bash -n dotty, and full ./test/bats/bin/bats test/.
