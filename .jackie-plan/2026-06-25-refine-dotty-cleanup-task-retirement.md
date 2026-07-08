---
id: 2026-06-25-refine-dotty-cleanup-task-retirement
title: Refine dotty cleanup task retirement
state: inbox
createdAt: 2026-06-25T16:35:56.708Z
updatedAt: 2026-07-08T22:53:21.335Z
---

# Refine dotty cleanup task retirement

## Plan

Related prior plan: `2026-06-24-design-dotty-one-shot-cleanup-tasks`.

Problem:
Dotty cleanup tasks currently run once per applicable local machine and record local receipts under `~/.dotty/cleanups/<repo>/<cleanup-id>/`. The repo task files remain tracked until someone manually removes them later. That matches the current docs, but temporary cleanup tasks can accumulate because there is no reminder, retirement workflow, or useful summary of when a cleanup is safe to delete.

Context:
- Dotfiles repos may be layered and run on different machines and environments.
- An earlier layer cannot directly know every later layer or machine that uses it.
- Cleanup configs already support `DOTTY_CLEANUP_ENVIRONMENTS` and `DOTTY_CLEANUP_MACHINES`, but receipts are local-only.
- Auto-deleting tracked cleanup files during `dotty update` is probably the wrong shape because it mutates repos locally and cannot prove global completion.

Explore a refinement that avoids persisting cleanup tasks forever without pretending local state is global truth.

Possible directions:
- Add a `dotty cleanups --retirable` or similar report for tasks that are done locally and have aged past a configurable window.
- Add metadata such as an intended retirement date/window, owner note, or target scope.
- Make `dotty doctor` or `dotty cleanups` warn about old completed cleanup tasks still tracked in the repo.
- Preserve explicit human removal through a follow-up commit, but make the prompt visible and low-friction.
- Consider whether machine-scoped cleanups can provide stronger local guarantees than environment-scoped cleanups.

Acceptance criteria:
- The design is explicit about what dotty can and cannot know across machines and layered repos.
- The workflow helps remove stale tracked cleanup files without unsafe auto-mutation.
- README docs and tests cover the selected behavior.

## Agent handoff

Related prior plan: `2026-06-24-design-dotty-one-shot-cleanup-tasks`.

Problem:
Dotty cleanup tasks currently run once per applicable local machine and record local receipts under `~/.dotty/cleanups/<repo>/<cleanup-id>/`. The repo task files remain tracked until someone manually removes them later. That matches the current docs, but temporary cleanup tasks can accumulate because there is no reminder, retirement workflow, or useful summary of when a cleanup is safe to delete.

Context:
- Dotfiles repos may be layered and run on different machines and environments.
- An earlier layer cannot directly know every later layer or machine that uses it.
- Cleanup configs already support `DOTTY_CLEANUP_ENVIRONMENTS` and `DOTTY_CLEANUP_MACHINES`, but receipts are local-only.
- Auto-deleting tracked cleanup files during `dotty update` is probably the wrong shape because it mutates repos locally and cannot prove global completion.

Explore a refinement that avoids persisting cleanup tasks forever without pretending local state is global truth.

Possible directions:
- Add a `dotty cleanups --retirable` or similar report for tasks that are done locally and have aged past a configurable window.
- Add metadata such as an intended retirement date/window, owner note, or target scope.
- Make `dotty doctor` or `dotty cleanups` warn about old completed cleanup tasks still tracked in the repo.
- Preserve explicit human removal through a follow-up commit, but make the prompt visible and low-friction.
- Consider whether machine-scoped cleanups can provide stronger local guarantees than environment-scoped cleanups.

Additional observed cleanup-retirement friction from a checkout consolidation:

- A deleted/retired cleanup task left an empty untracked directory at `.dotty/cleanups/2026-06-remove-legacy-gsd-core` in one checkout.
- `dotty update` treated that empty directory as a malformed cleanup and exited nonzero until the empty directory was removed.
- Existing local cleanup receipt `source` files stored absolute paths into the old registered checkout, so changing the registered checkout path made receipt metadata stale. Manual repair updated those local receipt paths after the visible checkout became the registered base repo.

This reinforces the existing plan's need for a clearer cleanup retirement workflow and diagnostics. It may also be worth deciding whether local receipt metadata should store repo-relative cleanup paths, tolerate missing sources for completed receipts, or offer a repair command after registered checkout path changes.

Acceptance criteria:
- The design is explicit about what dotty can and cannot know across machines and layered repos.
- The workflow helps remove stale tracked cleanup files without unsafe auto-mutation.
- README docs and tests cover the selected behavior.
