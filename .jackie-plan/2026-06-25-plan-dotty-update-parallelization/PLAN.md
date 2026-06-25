---
id: 2026-06-25-plan-dotty-update-parallelization
title: Plan dotty update parallelization
state: ready-to-ship
createdAt: 2026-06-25T17:07:01.451Z
updatedAt: 2026-06-25T17:44:15.361Z
---

# Plan dotty update parallelization

## Plan

## Objective

Implement a measured first pass that speeds up `dotty update` by parallelizing only git pulls for the resolved repo chain, while preserving all ordering-sensitive dotty behavior.

## Current implementation facts

- `pull_if_clean` lives in `dotty` around lines 377-406.
- `run_chain` lives around lines 754-799 and currently does, for each repo in chain order: optional pull, then `process_repo`.
- `process_repo` performs config loading, orphan cleanup, symlink creation, one-shot cleanup execution, and hooks. Those operations must remain serial and in chain order.
- `cmd_update <target>` pulls only the named repo, then runs the full chain with `pull=false`; this should remain serial for the first pass.
- `_DOTTY_CHANGES_MADE` is a parent-shell flag used by `_write_reload_marker`; background pull jobs cannot mutate it directly.
- Existing tests cover self-update, cleanup, chain resolution, symlinks, and dry-run behavior, but there is no focused coverage for repo-chain pull scheduling.

## Selected first implementation

Parallelize repo pulls for full-chain `dotty update` only, behind an opt-in environment variable:

- Add `DOTTY_UPDATE_JOBS` as the user-facing concurrency control.
- Default to `1`, preserving current serial behavior unless explicitly enabled.
- Use parallel pulls only when `command == update`, `pull == true`, dry-run is false, and normalized jobs is greater than `1`.
- Keep `dotty update <repo>` serial because it pulls a single target repo before processing the full chain.
- Keep `dotty install` serial for this first pass even though it also calls `run_chain "true"`; install has broader semantics and is not the measured target.

## Rationale

Repo pulls are separate git worktrees and are usually network-bound, so they are the lowest-risk useful place to introduce concurrency. Linking, cleanup tasks, and hooks all write shared state or run arbitrary user shell, so parallelizing them would risk changing dotty's core chain ordering contract.

Making the feature opt-in keeps the public default stable while allowing real-world timing data from personal usage. If this proves solid, a later plan can consider a small automatic default.

## Implementation shape

1. Add a helper to normalize `DOTTY_UPDATE_JOBS`.
   - Empty or unset means `1`.
   - Positive integers are accepted.
   - Invalid or less-than-one values warn and fall back to `1`.
   - Do not add a CLI flag in the first pass.

2. Keep the existing serial path untouched for `jobs == 1`.
   - This lowers regression risk and keeps current output timing unchanged by default.

3. Add a parallel pull helper for full-chain update pulls.
   - Create a temp directory under `${TMPDIR:-/tmp}` with `mktemp -d`.
   - For each repo, run the pull in a background subshell, redirecting stdout/stderr to a per-repo log file.
   - Record each job's before/after revision or changed marker in a per-repo result file so the parent shell can set `_DOTTY_CHANGES_MADE=true` if any repo changed.
   - Preserve current pull failure semantics: warn and continue, do not fail the chain, and abort any in-progress rebase for that repo.
   - Replay captured pull logs in deterministic chain order after all pulls complete and before serial processing begins.
   - Remove the temp directory on return.

4. Implement bounded concurrency without relying on Bash 4+ features.
   - macOS still commonly uses Bash 3.2.
   - Do not use `wait -n`.
   - A simple batch scheduler is acceptable for the first pass: launch up to `DOTTY_UPDATE_JOBS` jobs, wait for that batch, then launch the next batch. This is less perfectly saturated than a worker pool but is much simpler, portable, deterministic, and enough for short dotty chains.

5. Split the old `run_chain` loop only at the pull boundary.
   - Register all repos first as today.
   - If eligible for parallel pulls, run all pulls before serial `process_repo`.
   - Then process each repo in the original chain order.
   - If not eligible, keep the current per-repo pull-then-process loop.

## Tests to add

Add a focused Bats file, likely `test/update_parallel.bats`, with fake git or wrapped `pull_if_clean` where practical.

Required coverage:

- `DOTTY_UPDATE_JOBS` unset uses the current serial path.
- `DOTTY_UPDATE_JOBS=2` pulls before processing and still processes repos in chain order.
- Captured pull output is replayed in chain order even if individual pulls finish out of order.
- If any parallel pull changes revisions, the parent shell sets `_DOTTY_CHANGES_MADE=true` so `_write_reload_marker` can work.
- Pull warnings do not fail the update and do not set `_CHAIN_HAD_ERRORS`, matching current behavior.
- Dry-run skips pulls entirely.
- Invalid `DOTTY_UPDATE_JOBS` falls back to serial with a warning.

Implementation note for tests: prefer stubbing `pull_if_clean` or `git` inside Bats over creating real remotes unless real git behavior is specifically needed for the change-marker test. The scheduler behavior is the main new contract.

## Docs and help

If `DOTTY_UPDATE_JOBS` is added, update:

- `cmd_help()` environment variable list in `dotty`.
- `README.md` environment variable section.
- Any docs that describe update behavior if they imply purely serial pulls.

No zsh completion change is needed for an environment variable unless an established completions pattern exists for env vars.

## Non-goals

- Parallel linking.
- Parallel hooks.
- Parallel cleanup tasks.
- Parallel first-time clone or chain resolution.
- Changing pull failure behavior.
- Adding a `dotty update --jobs` flag.
- Making parallel pulls the default.

## Open design choices

Recommended defaults are now selected above. The only user-tunable decision worth revisiting before implementation is whether `DOTTY_UPDATE_JOBS` should default to a small automatic value such as `4` instead of `1`. I recommend keeping the default at `1` for the first public pass.

## Minimal-context implementation prompt

Resume Jackie Plan `2026-06-25-plan-dotty-update-parallelization` from the dotty repository root.

Use the `jackie-plan` skill. Start with:

`jp show 2026-06-25-plan-dotty-update-parallelization --json`

Implement the selected first pass only: opt-in parallel git pulls for full-chain `dotty update` via `DOTTY_UPDATE_JOBS`, defaulting to serial behavior. Preserve all serial behavior for linking, orphan cleanup, one-shot cleanups, hooks, install, dry-run, self-update, and `dotty update <repo>`.

Before editing, inspect `pull_if_clean`, `run_chain`, `cmd_update`, and the existing Bats helpers. Add focused Bats coverage for job normalization, pull-before-process behavior, deterministic log replay, change-marker propagation back to `_DOTTY_CHANGES_MADE`, preserved warning-and-continue semantics, and dry-run skipping pulls.

Keep Bash 3.2 portability. Do not use `wait -n`. A simple batch scheduler is acceptable. Update `cmd_help()` and `README.md` for `DOTTY_UPDATE_JOBS`. Run the smallest relevant Bats file while iterating, then `./test/bats/bin/bats test/`. Update/checkpoint the Jackie Plan, commit with a conventional commit, and push `main`.
