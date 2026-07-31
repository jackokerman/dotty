---
id: 2026-06-25-investigate-serial-update-dry-run-cost
title: Investigate serial update dry-run cost
state: ready-to-implement
priority: normal
createdAt: 2026-06-25T17:26:19.694Z
updatedAt: 2026-07-31T22:28:15.826Z
---

# Investigate serial update dry-run cost

## Plan

## Objective

Profile the non-network cost of `dotty status` and `dotty --dry-run update`, identify whether one avoidable low-risk bottleneck dominates, and capture a separate product-change plan only when the measurements justify it.

## Why proceed

The cost is current and large enough to investigate on the active two-repo chain:

- On 2026-07-31, `dotty --dry-run update` took 17.66 seconds (`user` 2.48s, `sys` 4.21s).
- On 2026-07-31, `dotty status` took 8.84 seconds (`user` 1.22s, `sys` 1.90s).
- The chain contains 470 source-tree entries and 304 leaf files, so the observed latency is disproportionate to the managed tree size.
- A read-only xtrace of `dotty status` counted 231 `git check-ignore`, 246 `basename`, 243 `dirname`, and 138 `readlink` subprocesses.
- A read-only xtrace of `dotty --dry-run update` counted 220 `git check-ignore` calls, 1,505 `basename` calls, 221 `dirname` calls, 453 `readlink` calls, 30 managed-checkout Git helper invocations, 131 orphan-cleanup recursion steps, and 218 link-item steps.

The first hypothesis is therefore subprocess-heavy per-entry traversal, especially `_is_gitignored`, rather than pull scheduling. This is a hypothesis to measure, not authorization to optimize it in this investigation.

## Scope and non-goals

- Measure read-only status and dry-run update behavior only. Do not run a real update for profiling.
- Keep temporary instrumentation and generated fixtures outside tracked files.
- Do not change caching, traversal, ignore semantics, status output, dry-run behavior, or `DOTTY_UPDATE_JOBS` in this plan.
- Do not mix managed-checkout network performance or hook runtime into the non-network result.

## Investigation approach

1. Establish baselines with at least three warm runs each of `dotty status` and `dotty --dry-run update`. Record wall, user, and system time for every run plus the median and range.
2. Attribute wall time for status across chain resolution, environment detection, per-repo Git dirty checks, and `_files_walk` link-health counting.
3. Attribute wall time for dry-run update across self-update short-circuiting, chain resolution, environment detection, managed-checkout inspection, orphan cleanup, link traversal, and pending-cleanup discovery.
4. Count subprocesses by phase. Inspect `_is_gitignored` first, then per-entry `basename`, `dirname`, and `readlink` calls, repeated tree walks, and managed-checkout Git inspection.
5. Compare the active chain against isolated temporary two-repo fixtures using a temporary `HOME` and `DOTTY_DIR`. Include:
   - a small control fixture;
   - a fixture near the active chain's entry count;
   - nested ignored files;
   - hidden files;
   - an overlay conflict that forces a real merged directory and per-entry traversal.
6. Vary fixture size enough to distinguish fixed command overhead from per-entry scaling. Do not rely on a single tiny fixture.
7. Record the dominant phase, subprocess counts, scaling behavior, expected wall-time improvement, and the correctness boundary any optimization must preserve.

## Correctness boundaries

Any follow-up optimization must preserve:

- nested `.gitignore` behavior and ignored-directory handling;
- `DOTTY_LINK_IGNORE` behavior;
- hidden-file traversal;
- directory-symlink short-circuiting and exploded directory merges;
- later-repo override semantics;
- status counts for linked, overridden, and unlinked files;
- dry-run output and its no-product-mutation contract.

## Decision and handoff

Treat a bottleneck as actionable only when repeated phase timings and fixture scaling agree that it explains a substantial share of wall time and a low-risk change should produce a meaningful absolute improvement.

- If one bottleneck meets that bar, capture a focused implementation plan. Name the exact functions and behavior to change, the correctness cases to cover, and representative before/after timing verification. Existing focused coverage starts in `test/commands.bats`, `test/symlinks.bats`, and `test/dry_run.bats`; add tests only for the boundary the proposed change could regress.
- If cost is distributed, machine-specific, or expected for the managed tree size, record that conclusion and complete this investigation without product changes.
- If separate bottlenecks affect status and dry-run update, do not combine them automatically; capture only independently justified follow-up work.

## Verification

- Re-run the baseline commands after instrumentation is removed to ensure tracing did not determine the result.
- Confirm `git status --short` is unchanged by the investigation.
- Preserve the measurements, conclusion, and any follow-up plan ID in this plan's checkpoint before completing it.

## Agent handoff

The user approved the persisted investigation contract on 2026-07-31, and the plan is now `ready-to-implement`.

A fresh implementation session should execute the measurement contract only. Start with repeated warm baselines and phase attribution, test the subprocess-heavy traversal hypothesis against scaling fixtures, and capture a separate focused product-change plan only if the evidence meets the decision bar. Do not optimize opportunistically or run a real update for profiling.
