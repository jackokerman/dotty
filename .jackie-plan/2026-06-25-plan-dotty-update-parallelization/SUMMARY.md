---
id: 2026-06-25-plan-dotty-update-parallelization
title: Plan dotty update parallelization
state: active
createdAt: 2026-06-25T17:07:01.451Z
updatedAt: 2026-06-25T17:07:35.386Z
---

Created a planning-only Jackie Plan for speeding up `dotty update` safely. Current recommendation is to parallelize repo pulls first while keeping self-update, chain resolution, linking, cleanups, hooks, reload marker handling, and summaries serial. The plan captures design questions around `DOTTY_UPDATE_JOBS`, default concurrency, deterministic output replay, failure semantics, stashed worktrees, and parent-shell change tracking from parallel jobs. Do not implement until those questions are settled and the plan is marked ready-to-implement.
