---
id: 2026-06-25-improve-dotty-repo-command-discoverability
title: Improve Dotty repo-command discoverability
state: complete
createdAt: 2026-06-25T03:23:22.317Z
updatedAt: 2026-07-31T21:48:38.272Z
sourcePlan: 2026-06-25-build-preferred-personal-tooling-stack
---

# Improve Dotty repo-command discoverability

## Plan

## Decision

No Dotty change is currently warranted.

## Verified current behavior

- `dotty commands` lists the active chain's repo-defined commands and owning repos.
- `dotty run <name>` has dedicated README command documentation and a full repo-command contract section.
- zsh completion for `dotty run <TAB>` calls `dotty commands` and completes stable command names.
- the installed completion file is linked into the standard site-functions directory on the audited machine.
- the active chain currently exposes multiple commands successfully through this surface.

The original plan explicitly said to follow up only if discoverability still felt weak after use. No concrete completion failure, confusing case, or repeated discovery problem has been captured. Adding command metadata or putting maintenance commands on `PATH` would be speculative.

## Outcome

Keep the existing command surface and documentation. Reopen with a concrete reproduction if completion fails after `dotty update`, users cannot find `dotty commands`, or stable command descriptions become necessary for a demonstrated picker or help workflow.
