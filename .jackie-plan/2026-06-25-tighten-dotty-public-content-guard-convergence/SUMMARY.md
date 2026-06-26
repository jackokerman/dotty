---
id: 2026-06-25-tighten-dotty-public-content-guard-convergence
title: Tighten Dotty public-content guard convergence
state: complete
createdAt: 2026-06-25T23:00:54.024Z
updatedAt: 2026-06-26T00:47:36.599Z
---

Completed the guard convergence cleanup. README setup now leads with `$XDG_CONFIG_HOME/public-content-guard/patterns`; `dotty guard-check --help` separates default pattern sources from override pattern sources; `dotty help` labels env vars as temporary/extra guard inputs; and `test/guard.bats` uses the machine-wide pattern file for the shared-source hook installation fixture. Verified `./test/bats/bin/bats test/guard.bats`, `./dotty guard-check --help`, the guard section of `./dotty help`, reference searches for guard docs, and the full `./test/bats/bin/bats test/` suite. Local sample checks found installed hooks in managed repos, but no tracked repo-local `.githooks/sensitive-content-patterns` files or inline env pattern definitions requiring a follow-up. Follow-up audit found no durable next item.
