---
id: 2026-06-25-investigate-serial-update-dry-run-cost
title: Investigate serial update dry-run cost
state: inbox
priority: low
createdAt: 2026-06-25T17:26:19.694Z
updatedAt: 2026-06-25T17:26:19.983Z
---

# Investigate serial update dry-run cost

## Plan

## Why

A measurement during the `dotty update` parallelization design pass showed `dotty --dry-run update` taking about 19s even though pulls and hooks are skipped. That suggests there may be a separate performance opportunity in serial link, orphan-cleanup, status, or dry-run reporting work.

## Relationship to parallel pulls

Keep this separate from `2026-06-25-plan-dotty-update-parallelization`. The parallel-pulls implementation should stay scoped to opt-in pull concurrency; this plan is for later profiling of non-pull update cost.

## Acceptance criteria

- Profile `dotty --dry-run update`, `dotty status`, and a real or simulated no-op `dotty update` enough to separate link scanning, orphan cleanup, status rendering, and hook/pull costs.
- Identify whether the cost is expected for large config trees or caused by avoidable repeated scans.
- Capture a focused implementation plan only if profiling finds a clear bottleneck with a low-risk fix.
