---
id: 2026-06-25-refine-dotty-cleanup-task-retirement
title: Refine dotty cleanup task retirement
state: inbox
createdAt: 2026-06-25T16:35:56.708Z
updatedAt: 2026-07-31T21:48:38.058Z
---

# Refine dotty cleanup task retirement

## Plan

## Objective

Decide the smallest honest cleanup-retirement workflow from current local-only receipt semantics, and fix only concrete operational defects found along that path.

## Verified current contract

Cleanup tasks are tracked under `.dotty/cleanups/`; successful and failed attempts write local receipts under `~/.dotty/cleanups/<repo>/<cleanup-id>/`. Dotty cannot infer completion on other machines or in unknown downstream layers. Removing tracked cleanup tasks therefore remains an explicit source-repo decision.

Current receipts store an absolute script path as diagnostic metadata. A checkout-path migration can make that metadata stale, but execution and completion checks are keyed by repo name and cleanup id, so the stale `source` value does not invalidate a completed receipt.

## Concrete observed friction

- completed task definitions accumulate because there is no visible retirement prompt;
- deleting one task left an empty untracked task directory in a checkout, which Dotty correctly reported as malformed until the directory was removed;
- receipt `source` metadata retained an obsolete absolute checkout path after a registry migration.

## Investigation contract

Start with a design and fixture pass; do not assume a new command or metadata field is needed.

- Reproduce retirement of a completed directory-shaped task in a temporary repo and distinguish Git/untracked-directory behavior from Dotty linking behavior.
- Verify whether any command consumes receipt `source`; if it remains diagnostic-only, do not add migration or fallback parsing for old absolute values.
- Compare two minimal options: clearer docs for explicit task removal, or one local-only `dotty cleanups` indication that a completed tracked task is a retirement candidate.
- Reject any design that claims cross-machine completion, auto-deletes tracked source, mutates a managed repo, or introduces configurable aging without demonstrated need.
- Prefer no core feature if the empty directory is external checkout residue and local receipt metadata has no behavioral effect.

## Exit criteria

Either complete this plan with a documented no-change decision, or revise it into one implementation contract that names the exact command/output change, metadata semantics, focused Bats fixtures, and README/help/completion updates required.

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
