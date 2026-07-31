---
id: 2026-07-31-batch-git-ignore-checks-during-dotty-traversal
title: Batch Git ignore checks during Dotty traversal
state: inbox
createdAt: 2026-07-31T22:45:29.537Z
updatedAt: 2026-07-31T22:45:29.537Z
sourcePlan: 2026-06-25-investigate-serial-update-dry-run-cost
---

# Batch Git ignore checks during Dotty traversal

## Plan

## Objective

Replace subprocess-per-entry Git ignore checks in status and link traversal with one batched ignore classification per source tree or another equivalently bounded approach, while preserving current ignore and traversal semantics.

## Evidence

The source investigation measured the active two-repo chain on 2026-07-31:

- Warm `dotty status` median: 7.01s. `_files_walk` alone took 7.03s and launched 231 `git check-ignore`, 247 `basename`, 243 `dirname`, and 138 `readlink` subprocesses.
- Warm `dotty --dry-run update` median: 13.05s. Link traversal took about 7.33s, orphan cleanup about 4.65s, and managed-checkout inspection 0.39–0.89s warm. Link traversal launched 220 `git check-ignore` calls.
- A temporary upper-bound override that made `_is_gitignored` return false reduced warm status to a 1.89s median and warm dry-run update to a 7.10s median. This isolates roughly 5–6 seconds of avoidable wall time without changing other traversal work.
- Isolated two-repo fixtures scaled nearly linearly: warm status was 1.14s at 39 entries, 3.97s at 135 entries, and 14.29s at 495 entries; dry-run update was 1.61s, 5.81s, and 22.54s respectively.

## Implementation scope

- Change the ignore-classification boundary used by `_files_walk` in `dotty` and `create_symlinks_from_dir` in `lib/utils.sh` so traversal does not invoke `_is_gitignored` once per entry.
- Prefer a single explicit source of truth for the batched result. Do not add a cache lifetime, environment override, fallback implementation, or parallel configuration path unless a demonstrated correctness boundary requires it.
- Remove or narrow `_is_gitignored` if the new boundary makes it obsolete.
- Do not combine orphan-cleanup optimization into this change.

## Correctness boundaries

Preserve:

- nested `.gitignore` rules and ignored-directory handling;
- hidden-file traversal;
- `DOTTY_LINK_IGNORE` behavior;
- directory-symlink short-circuiting and exploded directory merges;
- later-repo override semantics;
- status counts for linked, overridden, and unlinked files;
- dry-run output and its no-product-mutation contract.

## Verification

- Add focused coverage only for the batching boundary, using the existing behavior coverage in `test/commands.bats`, `test/symlinks.bats`, and `test/dry_run.bats` where appropriate.
- Run the smallest relevant Bats files, then the full suite.
- Repeat representative warm timings on the active chain and a near-500-entry isolated fixture. Compare status and dry-run update against the source investigation medians above.
