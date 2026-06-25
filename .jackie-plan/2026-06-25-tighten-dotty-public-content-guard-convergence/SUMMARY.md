---
id: 2026-06-25-tighten-dotty-public-content-guard-convergence
title: Tighten Dotty public-content guard convergence
state: inbox
createdAt: 2026-06-25T23:00:54.024Z
updatedAt: 2026-06-25T23:00:54.024Z
---

# Summary

# Tighten Dotty public-content guard convergence

Audit the remaining Dotty-side guard surfaces so repos can converge on one setup model: machine-wide public-content patterns plus `dotty guard` installed per repo.

Scope:
- Review Dotty docs, examples, and tests that still present `PUBLIC_CONTENT_GUARD_PATTERNS` as a normal first-choice setup path.
- Decide whether env-var patterns should remain only as an escape hatch/test harness mechanism rather than a documented primary workflow.
- Check a small sample of repos that already opt into `dotty guard-check` to see whether any still inline patterns instead of relying on the shared machine-wide file and repo hook install.
- If cleanup is needed, update Dotty docs/steering and capture any per-repo follow-ups separately.

Why now:
- `jackie-plan` needed cleanup after a public-repo doc briefly linked an internal host and the repo was only partially converged on the shared guard workflow.
- The desired steady state is one shared source of truth for patterns, not per-repo inline fallbacks.
