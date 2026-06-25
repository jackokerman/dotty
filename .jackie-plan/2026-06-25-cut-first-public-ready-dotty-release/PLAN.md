---
id: 2026-06-25-cut-first-public-ready-dotty-release
title: Cut first public-ready dotty release
state: ready-to-implement
createdAt: 2026-06-25T00:39:16.965Z
updatedAt: 2026-06-25T00:39:21.995Z
---

# Cut first public-ready dotty release

## Plan

# Cut first public-ready dotty release

## Source
Migrated from `ROADMAP.md` during roadmap cleanup.

## Why
Sharing a named release is more stable than asking users to install from a moving `main` branch.

## Outcome
Dotty has a first public-ready tagged release with clear release notes.

## Acceptance criteria
- Confirm the current public-ready baseline is green on `main`.
- Bump `DOTTY_VERSION` if needed.
- Create release notes summarizing the public baseline.
- Push the release tag.
- Verify the install path references the intended release or intentionally remains on `main`.

## Notes
This is release mechanics, not product work. If the user asks for implementation work, prefer the onboarding pass plan first.
