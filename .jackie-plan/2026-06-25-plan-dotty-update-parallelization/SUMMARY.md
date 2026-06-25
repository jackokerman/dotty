---
id: 2026-06-25-plan-dotty-update-parallelization
title: Plan dotty update parallelization
state: ready-to-ship
createdAt: 2026-06-25T17:07:01.451Z
updatedAt: 2026-06-25T17:44:15.361Z
---

Implemented the selected first pass for opt-in parallel git pulls during full-chain `dotty update`.

Changed `dotty` to normalize `DOTTY_UPDATE_JOBS`, defaulting to `1`; values greater than `1` run chain repo pulls in Bash 3.2-compatible batches before serial repo processing. The default serial pull-then-process path remains separate. The parallel path is only eligible for `run_chain true update` when not in dry-run mode, so `install`, self-update, dry-run, and `dotty update <repo>` keep serial/no-pull behavior. Parallel pull logs are captured and replayed in chain order, and child `_DOTTY_CHANGES_MADE` state is propagated back to the parent for reload marker handling.

Added `test/update_parallel.bats` covering job normalization, default serial behavior, pull-before-process behavior, deterministic replay, change marker propagation, warning-and-continue behavior, dry-run pull skipping, and install/no-pull update preservation. Updated `cmd_help()` and `README.md` for `DOTTY_UPDATE_JOBS`.

Verification passed:
- `./test/bats/bin/bats test/update_parallel.bats`
- `bash -n dotty test/update_parallel.bats`
- `git diff --check`
- `./test/bats/bin/bats test/`

Repo status before commit contained only intended changes: `README.md`, `dotty`, and `test/update_parallel.bats`.
