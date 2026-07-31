---
id: 2026-06-25-decide-whether-dotty-needs-init-or-starter-profiles
title: Decide whether dotty needs init or starter profiles
state: complete
createdAt: 2026-06-25T00:39:17.023Z
updatedAt: 2026-07-31T21:48:38.231Z
---

# Decide whether dotty needs init or starter profiles

## Plan

## Decision

Do not add `dotty init`, starter profiles, or another generator.

## Evidence

The completed outside-user onboarding pass exercised the checked-in layered examples in clean temporary homes. It found one concrete issue: the work example used a placeholder dependency URL. Dotty fixed that boundary by resolving repo-relative `DOTTY_EXTENDS` paths, pointing the example overlay at the checked-in base example, and documenting a runnable example install flow.

After that fix, the README-shaped clean-room flow passed against pushed `main`. The repository now provides concrete `examples/personal-dotfiles/` and `examples/work-dotfiles/` starting points without adding a second configuration or generation surface.

## Outcome

Docs and examples are sufficient for the observed onboarding friction. A generator would add product and maintenance surface without solving a remaining demonstrated problem. Reconsider only if new outside-user evidence shows repeated setup work that cannot be addressed directly in the examples or install documentation.
