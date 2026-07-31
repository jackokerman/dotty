---
id: 2026-06-25-investigate-serial-update-dry-run-cost
title: Investigate serial update dry-run cost
state: inbox
priority: normal
createdAt: 2026-06-25T17:26:19.694Z
updatedAt: 2026-07-31T21:48:38.443Z
---

# Investigate serial update dry-run cost

## Plan

## Objective

Profile the non-network cost of read-only and dry-run Dotty workflows, then capture a separate implementation plan only if measurement identifies one clear low-risk bottleneck.

## Refreshed evidence

On the active two-repo chain on 2026-07-31:

- `dotty --dry-run update` took 17.66 seconds (`user` 2.48s, `sys` 4.21s).
- `dotty status` took 8.84 seconds (`user` 1.22s, `sys` 1.90s).

The dry run skipped pulls and install actions but still resolved the chain, inspected managed checkouts, and scanned link state. The old approximately 19-second observation is therefore still representative, and the status timing shows the cost is not limited to update pull scheduling.

## Investigation contract

Keep this as measurement work, not an assumed optimization.

- Measure at least three warm runs of `dotty status` and `dotty --dry-run update`.
- Use temporary instrumentation outside tracked files where practical to time chain resolution, managed-checkout inspection, environment detection, link-state counting, orphan scanning, and dry-run link traversal separately.
- Compare the active layered chain with a small temporary fixture so machine-specific tree size is distinguishable from fixed command overhead.
- Inspect repeated full-tree scans and subprocess-heavy loops first; do not add caching before identifying the dominant repeated work.
- Record the bottleneck, expected improvement, and correctness boundary.

## Exit criteria

- If one low-risk bottleneck dominates, capture a focused implementation plan with regression tests and representative timing verification.
- If cost is distributed or expected for the managed tree size, record that conclusion and complete this investigation without product changes.

Do not mix this work with changing the `DOTTY_UPDATE_JOBS` default.
