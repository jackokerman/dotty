---
id: 2026-06-25-evaluate-default-concurrency-for-update-pulls
title: Evaluate default concurrency for update pulls
state: inbox
createdAt: 2026-06-25T17:25:45.357Z
updatedAt: 2026-06-25T17:25:45.357Z
---

# Evaluate default concurrency for update pulls

## Plan

## Related plan

Source plan: `2026-06-25-plan-dotty-update-parallelization`.

## Why

The first parallel update implementation should ship as opt-in through `DOTTY_UPDATE_JOBS`, defaulting to serial behavior. After it is available, revisit whether dotty should choose a small automatic default such as `4`.

## Trigger

Pick this up after the opt-in parallel pull implementation has been used on real chains for a bit.

## Acceptance criteria

- Gather before/after timings for `dotty update` with `DOTTY_UPDATE_JOBS=1`, `2`, and `4` on at least one short chain and one longer or slower chain if available.
- Separate pull time from serial link, cleanup, and hook time so the decision is not based on total runtime alone.
- Decide whether to keep the feature opt-in, document a recommended env var, or make a bounded parallel default.
- If a default greater than `1` is selected, update docs and tests in the implementation change.
