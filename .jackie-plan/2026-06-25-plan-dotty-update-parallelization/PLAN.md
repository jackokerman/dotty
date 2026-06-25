---
id: 2026-06-25-plan-dotty-update-parallelization
title: Plan dotty update parallelization
state: active
createdAt: 2026-06-25T17:07:01.451Z
updatedAt: 2026-06-25T17:07:35.386Z
---

# Plan dotty update parallelization

## Plan

## Objective

Decide and specify a safe, incremental design for speeding up `dotty update` through narrowly scoped parallelism, then implement it only after the ordering guarantees and compatibility guardrails are clear.

## Current understanding

`dotty update` currently runs in a linear sequence:

1. Self-update dotty itself.
2. Resolve the active repo chain.
3. For each repo in chain order, optionally pull, link files, run pending cleanups, and run `.dotty/run.sh`.

The chain order is semantically important because later repos override earlier repos during linking. Hooks and cleanup tasks are arbitrary shell and may depend on earlier steps having completed.

## Recommended first implementation target

Parallelize repo pulls only.

Keep these steps serial:

- Dotty self-update.
- Chain resolution.
- Symlink creation and orphan cleanup.
- One-shot cleanup execution.
- `.dotty/run.sh` hooks.
- Final reload marker and status/error summaries.

Repo pulls are the safest initial target because they operate on separate git worktrees and are often network-bound. They still need bounded concurrency, stable output, and careful aggregation of failures.

## Design questions to settle before implementation

- Should parallel pulls be opt-in first, for example `DOTTY_UPDATE_JOBS=4`, or should dotty choose a small default automatically?
- What should be the default job count? Conservative option: keep default `1` and document the env var. More ambitious option: default to a small bounded value such as `4`.
- Should `dotty update <repo>` remain fully serial because it only pulls one repo, or should shared helper code still cover it?
- How should pull output be shown? Preferred direction: capture per-repo logs and replay failures or concise summaries in chain order.
- How should failure semantics behave? Current behavior warns on failed pull and continues. Preserve that unless planning identifies a concrete reason to change it.
- How should stashed dirty worktrees behave under parallel pulls? `pull_if_clean` currently stashes and pops inside each repo. Confirm separate worktrees make this safe enough under bounded parallel execution.
- How should `_DOTTY_CHANGES_MADE` be updated from parallel jobs? Subshells cannot mutate parent shell state directly, so each job likely needs a small result file.

## Guardrails

- Do not parallelize linking; it writes overlapping `$HOME` paths and relies on overlay order.
- Do not parallelize `.dotty/run.sh`; hooks are arbitrary shell.
- Do not parallelize existing one-shot cleanups by default; cleanups are arbitrary shell and their receipt state is local mutable state.
- Do not change the externally visible repo chain order or later-repo-wins behavior.
- Preserve dry-run behavior: pulls are skipped entirely during dry-run.
- Keep GNU/BSD portability and Bash compatibility.

## Potential implementation sketch

1. Add a small helper to normalize the desired update job count from an env var, likely `DOTTY_UPDATE_JOBS`.
2. Add a bounded parallel pull helper that accepts chain paths, launches `pull_if_clean` jobs up to the limit, writes each job's output/status/change marker to a temp directory, waits for all jobs, and replays output in deterministic chain order.
3. Refactor `run_chain` so pull handling can happen before serial `process_repo` when `pull=true` and jobs are greater than `1`.
4. Preserve current serial path for `DOTTY_UPDATE_JOBS=1` to reduce risk and simplify fallback.
5. Add Bats coverage using fake `git` or temporary repos to prove bounded parallel scheduling, deterministic failure summaries, and unchanged serial behavior.
6. Update docs and completions if a user-facing env var or flag is added.

## Validation plan

- Run the smallest relevant Bats tests while iterating, likely chain/update-related tests plus any new test file.
- Run the full suite: `./test/bats/bin/bats test/`.
- If changing docs or command help, check `cmd_help()`, `README.md`, and `completions/_dotty` stay in sync.
- Optionally validate against a temporary multi-repo dotty chain before trying a real local setup.

## Non-goals for the first pass

- Parallel linking.
- Parallel hooks.
- A new hook/task framework.
- First-time clone DAG parallelization.
- Changing failure behavior from warning-and-continue to fail-fast.
