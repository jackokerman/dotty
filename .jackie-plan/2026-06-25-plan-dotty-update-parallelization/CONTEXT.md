---
id: 2026-06-25-plan-dotty-update-parallelization
title: Plan dotty update parallelization
state: ready-to-implement
createdAt: 2026-06-25T17:07:01.451Z
updatedAt: 2026-06-25T17:25:11.529Z
---

## Local measurement note

A non-mutating timing pass used `git fetch --dry-run --quiet` to estimate the current pull parallelization ceiling. On a local two-repo chain, serial chain fetch took about 2.42s and parallel chain fetch took about 2.06s. Including a serial dotty self fetch before the chain, the serial estimate was about 2.29s and self-then-parallel-chain estimate was about 2.03s. These single-run timings are noisy but suggest the first-pass feature is testable and modestly useful on short chains.

A separate `dotty --dry-run update` run took about 19.09s with pulls and hooks skipped, which means pull parallelization is not the only meaningful performance opportunity. Keep the first pass scoped to parallel pulls, but consider follow-up measurement for link/status/update dry-run costs after the pull feature exists.
