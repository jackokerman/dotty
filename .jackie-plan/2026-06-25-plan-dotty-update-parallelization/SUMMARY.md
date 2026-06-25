---
id: 2026-06-25-plan-dotty-update-parallelization
title: Plan dotty update parallelization
state: ready-to-implement
createdAt: 2026-06-25T17:07:01.451Z
updatedAt: 2026-06-25T17:21:44.541Z
---

Design pass completed. The selected first implementation is opt-in parallel git pulls for full-chain `dotty update` via `DOTTY_UPDATE_JOBS`, defaulting to `1` so current behavior remains serial unless explicitly enabled. Scope excludes install, self-update, dry-run, targeted `dotty update <repo>`, linking, orphan cleanup, one-shot cleanups, and hooks. Implementation should split `run_chain` only at the pull boundary, run eligible pulls before serial `process_repo`, capture per-repo logs/results in temp files, replay logs in chain order, propagate any changed repo back to `_DOTTY_CHANGES_MADE`, and preserve current warning-and-continue pull failure semantics. Bash 3.2 portability matters; avoid `wait -n`, and a simple batch scheduler is acceptable. The canonical plan includes a minimal-context implementation prompt.
