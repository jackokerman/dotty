---
id: 2026-06-25-explore-targeted-dotty-refreshes
title: Explore targeted Dotty refreshes
state: ready-to-implement
createdAt: 2026-06-25T18:28:43.071Z
updatedAt: 2026-06-30T01:16:14.296Z
---

Implemented the docs-only refresh ladder slice.

Changed:
- Added `README.md` guidance for choosing between no Dotty command, `dotty link [name]`, `dotty update <name>`, `dotty update`, and `dotty self-update`.
- Added a compact `Refresh guide` section to `dotty help` with the same command-selection boundaries.
- Documented that generic Dotty intentionally does not classify repo-specific changed paths and that repo-specific strategies belong in managed repo docs, repo-defined `dotty run` commands, or domain-specific tooling.
- Kept the operation lock framed as the safety boundary for overlapping mutating commands, not as a refresh selector.

Verification:
- `./dotty help`
- `bash -n dotty`
- `./test/bats/bin/bats test/` (145 tests passed; log at `/tmp/dotty-bats-refresh-docs.log`)

Process notes:
- No objective process friction surfaced. The existing plan was accurate and the repository had no unrelated dirty work.
