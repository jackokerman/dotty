---
id: 2026-07-31-batch-git-ignore-checks-during-dotty-traversal
title: Batch Git ignore checks during Dotty traversal
state: ready-to-implement
createdAt: 2026-07-31T22:45:29.537Z
updatedAt: 2026-07-31T22:59:05.417Z
sourcePlan: 2026-06-25-investigate-serial-update-dry-run-cost
---

# Batch Git ignore checks during Dotty traversal

## Plan

## Objective

Replace subprocess-per-entry Git ignore checks in status and link traversal with one batched ignore classification per top-level source tree, while preserving current ignore and traversal behavior.

## Evidence and decision

The source investigation measured the active two-repo chain on 2026-07-31:

- Warm `dotty status` median: 7.01s. `_files_walk` alone took 7.03s and launched 231 `git check-ignore` subprocesses.
- Warm `dotty --dry-run update` median: 13.05s. Link traversal took about 7.33s and launched 220 `git check-ignore` subprocesses.
- Making `_is_gitignored` return false in a temporary measurement-only override reduced the warm medians to 1.89s and 7.10s respectively, isolating roughly 5–6 seconds of avoidable wall time.
- Isolated fixtures scaled nearly linearly: warm status was 1.14s at 39 entries, 3.97s at 135 entries, and 14.29s at 495 entries; dry-run update was 1.61s, 5.81s, and 22.54s respectively.

Use one `git ls-files -z --others --ignored --exclude-standard --directory -- .` query per top-level source tree. Local verification confirmed that it matches the relevant `git check-ignore` behavior for nested rules, negation, ignored empty and non-empty directories, tracked descendants inside a matching directory, standard excludes, and non-Git source trees. On the active chain, one query for each current `home/` tree took about 0.56s total and returned two ignored entries.

## Implementation contract

- Add one private helper in `lib/utils.sh` that refreshes the ignored-path snapshot for a supplied source-tree root.
- Read Git output as NUL-delimited records into a Bash 3.2-compatible indexed array. Normalize the trailing slash emitted for collapsed ignored directories and store paths in the same absolute form consumed by traversal.
- Narrow `_is_gitignored` to an exact lookup against the prepared snapshot, or replace it with an equivalently named predicate. Do not retain the per-entry Git fallback.
- Refresh the snapshot once when the outermost `create_symlinks_from_dir` call begins. Recursive calls must reuse it.
- Give `_files_walk` an outermost-call boundary, using a small wrapper or depth guard, so each `home/` or environment-overlay tree prepares one snapshot and recursive calls reuse it.
- Use the same helper and snapshot representation for link traversal and status/files traversal. Do not create separate implementations or configurable modes.
- Keep the implementation compatible with macOS Bash 3.2 and GNU/BSD userlands; do not use associative arrays or GNU-only parsing utilities.

## Correctness boundaries

Preserve:

- nested `.gitignore` rules, negation, ignored files, and ignored-directory pruning;
- Git's current treatment of tracked paths as non-ignored;
- standard ignore sources: per-directory `.gitignore`, `.git/info/exclude`, and the user's global excludes file;
- linking all otherwise eligible files when the source tree is not inside a Git worktree;
- hidden-file traversal and filenames handled safely by NUL-delimited Git output;
- `DOTTY_LINK_IGNORE` behavior;
- directory-symlink short-circuiting and exploded directory merges;
- later-repo override semantics;
- status counts for linked, overridden, and unlinked files;
- dry-run output and its no-product-mutation contract.

Do not add nested-Git-repository discovery inside a managed source tree. Dotty does not consistently support nested repositories today, and this optimization must not expand that surface.

## Focused tests

- Extend `test/symlinks.bats` with the classification cases not already covered: an ignored directory, a negated path, and a tracked descendant that prevents the directory itself from being classified as ignored.
- Add a focused assertion that a top-level link traversal performs one Git ignore-enumeration command regardless of entry count and that recursion does not refresh the snapshot.
- Extend the existing `cmd_files`/`cmd_status` coverage in `test/commands.bats` only enough to prove those walkers use the same snapshot semantics and one classification command per top-level tree.
- Keep the existing non-Git, hidden-file, `DOTTY_LINK_IGNORE`, overlay, symlink-merge, status-count, and dry-run tests as the broader regression contract. Do not duplicate them.

## Non-goals

- Do not optimize orphan cleanup, `basename`, `dirname`, `readlink`, managed-checkout inspection, or other traversal subprocesses in this change.
- Do not add a cache lifetime, environment override, fallback implementation, persistent daemon, temporary on-disk index, or parallel configuration path.
- Do not change command output, help, completions, README guidance, or public helper signatures unless implementation reveals an actual behavior change.

## Verification

1. Run the focused `test/symlinks.bats`, `test/commands.bats`, and `test/dry_run.bats` files.
2. Run `./test/bats/bin/bats test/`.
3. Confirm instrumentation or focused tests show one ignore-enumeration Git subprocess per top-level source tree and no per-entry `git check-ignore` calls.
4. Repeat at least three warm runs each of `dotty status` and `dotty --dry-run update` on the active chain. Compare medians with 7.01s and 13.05s; require at least a 30% reduction in both before considering the performance objective met.
5. Repeat representative warm timings on the near-500-entry isolated fixture from the source investigation. Confirm runtime no longer scales with one Git subprocess per traversed entry and improves by at least 30% from the 14.29s status and 22.54s dry-run medians.
6. Confirm `git status --short` is unchanged by timing runs and no real update is used for profiling.

## Review boundary

Before implementation, review this persisted contract and explicitly approve marking it `ready-to-implement`. Implementation may proceed in one pass once approved; pause only if `git ls-files` fails a preserved behavior case, the batching boundary requires a user-facing contract change, or the 30% performance target is missed after correctness tests pass.

## Agent handoff

The user reviewed and approved the persisted implementation contract. The plan is now `ready-to-implement`.

Implement the approved `git ls-files -z --others --ignored --exclude-standard --directory -- .` snapshot boundary as specified, preserving the focused correctness and performance gates. No implementation, commit, or push occurred during planning.
