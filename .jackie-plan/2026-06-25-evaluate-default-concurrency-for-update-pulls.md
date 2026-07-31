---
id: 2026-06-25-evaluate-default-concurrency-for-update-pulls
title: Evaluate default concurrency for update pulls
state: paused
createdAt: 2026-06-25T17:25:45.357Z
updatedAt: 2026-07-31T21:48:38.312Z
---

# Evaluate default concurrency for update pulls

## Plan

## Objective

Decide whether full-chain `dotty update` should keep serial pulls by default or use a small bounded `DOTTY_UPDATE_JOBS` default.

## Current state

Opt-in parallel pulls shipped with `DOTTY_UPDATE_JOBS`, defaulting to `1`. Pulls are the only parallelized stage; linking, cleanups, hooks, install, dry-run, self-update, and targeted updates remain serial.

There is not yet durable before/after evidence from both a short chain and a longer or slower chain. The original two-repo design measurement showed only a modest and noisy improvement, so changing the public default now would be guesswork.

## Resume trigger

Resume only after normal usage or a deliberate benchmark can provide repeatable timings for jobs `1`, `2`, and `4` on at least two materially different chains.

## Decision contract

When resumed:

- measure pull time separately from serial processing time;
- use repeated runs rather than a single timing;
- record chain size and whether remotes were already warm;
- keep the default at `1` unless a higher value produces a consistent material improvement without confusing output or remote pressure;
- if the default changes, update README/help and focused update-parallel tests in the same change.

Do not add a CLI flag or automatic CPU-based tuning.
