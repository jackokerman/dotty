---
id: 2026-06-25-explore-targeted-dotty-refreshes
title: Explore targeted Dotty refreshes
state: inbox
createdAt: 2026-06-25T18:28:43.071Z
updatedAt: 2026-06-25T18:28:43.071Z
---

# Summary

# Objective

Explore whether Dotty should support a narrower, deterministic refresh path for changes that do not need a full `dotty update`, and whether queued/coalesced update behavior is worth adding after operation locking.

# User problem

The safe default is currently to run `dotty update` after tracked config changes, but some edits clearly do not need the full update cycle. A broad update pulls repos, relinks the chain, runs hooks, and can trigger downstream workflows in managed setups. Operation locking prevents overlapping mutation, but it can still make agents wait behind unnecessary broad work.

# Design questions

- Can Dotty classify common changes into required refresh levels?
  - no live refresh needed;
  - `dotty link` enough;
  - generated config or repo hook refresh needed;
  - full `dotty update` needed.
- Should Dotty expose a command that recommends the smallest refresh based on changed paths, or is this better as downstream guidance?
- Is there a deterministic way to queue/coalesce update requests after the existing operation lock, or is waiting on the lock sufficient?
- Should a second `dotty update` request made while one is running become a pending follow-up, or simply wait and then return because the first update already refreshed state?
- How should this interact with dry-runs, hooks, cleanups, and repo-defined `dotty run` commands?

# Constraints

- Avoid overengineering. The existing operation lock already solves the safety issue.
- Do not rely on agents deciding from scratch whether broad refresh is safe.
- Keep behavior portable and deterministic in shell.
- Keep Dotty open-source and generic; managed repo-specific path heuristics belong downstream.
- Prefer an inspect/recommend command before adding automatic path classification that could be wrong.

# Potential first slice

Add documentation and/or a small `dotty refresh-plan` style command that explains the current refresh ladder and, optionally, reads Git status from registered repos to recommend one of:

- no Dotty command needed;
- `dotty link`;
- `dotty update <repo>`;
- full `dotty update`.

If queueing is explored, prefer coalescing semantics over a long FIFO: multiple pending full updates should collapse into one final update, because Dotty updates shared state to the latest repo state rather than applying independent user transactions.

# Acceptance criteria

- Future agents can choose a smaller deterministic refresh path when a change cannot affect generated or linked runtime output.
- The operation lock remains the safety boundary for mutating commands.
- Any queueing design is explicitly justified as reducing redundant work, not replacing locking.
- Tests or shell-level validation cover any new command or lock behavior.
