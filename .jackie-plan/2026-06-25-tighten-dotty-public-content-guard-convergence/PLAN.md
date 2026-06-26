---
id: 2026-06-25-tighten-dotty-public-content-guard-convergence
title: Tighten Dotty public-content guard convergence
state: complete
createdAt: 2026-06-25T23:00:54.024Z
updatedAt: 2026-06-26T00:47:36.599Z
---

# Tighten Dotty public-content guard convergence

## Plan

Audit and tighten Dotty's public-content guard guidance so the documented setup converges on one steady-state model: install `dotty guard` per public repo, and keep reusable sensitive-content patterns in the machine-wide public-content guard file.

Implementation scope:
- Make README setup lead with `$XDG_CONFIG_HOME/public-content-guard/patterns` and `dotty guard`, not inline `PUBLIC_CONTENT_GUARD_PATTERNS`.
- Keep repo-local `.githooks/sensitive-content-patterns`, `--patterns-file`, `PUBLIC_CONTENT_GUARD_PATTERN_FILE`, and `PUBLIC_CONTENT_GUARD_PATTERNS` as supported escape hatches for repo-specific, one-off, and test/CI use.
- Align the guard help text and focused tests with that model so the fixture named as a shared source actually uses the shared machine-wide pattern file.
- Check the local Dotty chain and nearby opted-in repos for remaining inline pattern usage, and capture any out-of-scope repo cleanup separately.

Verification:
- Run the focused guard bats test.
- Run a short docs/help text search for public-content guard references.
