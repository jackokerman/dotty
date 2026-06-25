---
id: 2026-06-25-decide-whether-dotty-needs-init-or-starter-profiles
title: Decide whether dotty needs init or starter profiles
state: inbox
createdAt: 2026-06-25T00:39:17.023Z
updatedAt: 2026-06-25T00:39:17.023Z
---

# Summary

# Decide whether dotty needs init or starter profiles

## Source
Migrated from `ROADMAP.md` during roadmap cleanup.

## Why
One-step onboarding could help adoption, but `dotty init`, starter profiles, or richer starter repo kits add product and maintenance surface area.

## Outcome
A decision is made from onboarding evidence, with the chosen path justified against the simpler example-based approach.

## Acceptance criteria
- Review friction captured from the outside-user onboarding pass.
- Identify whether docs/examples alone are enough.
- If tooling is warranted, define the smallest starter workflow that solves observed friction.
- If tooling is not warranted, document why the current example-based approach remains preferable.

## Dependency
Do this after the onboarding pass produces evidence.
