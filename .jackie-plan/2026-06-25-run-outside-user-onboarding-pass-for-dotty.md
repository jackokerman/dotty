---
id: 2026-06-25-run-outside-user-onboarding-pass-for-dotty
title: Run outside-user onboarding pass for dotty
state: complete
createdAt: 2026-06-25T00:39:16.997Z
updatedAt: 2026-06-25T20:13:12.069Z
---

# Run outside-user onboarding pass for dotty

## Plan

# Run outside-user onboarding pass for dotty

## Source
Migrated from `ROADMAP.md` during roadmap cleanup.

## Why
The remaining readiness questions are mostly about whether fresh users can install from the docs and examples without handholding.

## Outcome
A few outside users or clean-room installs surface concrete onboarding friction, and follow-up gaps are captured as Jackie Plans or GitHub issues.

## Acceptance criteria
- Run at least one clean-room install from current public docs.
- Ask a small number of outside users to follow the install and example path, or simulate that flow with fresh temporary home directories.
- Record concrete friction with reproduction steps.
- Capture follow-up work as separate Jackie Plans or GitHub issues.
- Avoid adding starter tooling until the evidence shows docs/examples are insufficient.

## Agent handoff

Ran the outside-user onboarding pass via clean-room temp homes. Found that `examples/work-dotfiles` used a placeholder GitHub URL in `DOTTY_EXTENDS`, so installing the checked-in examples immediately failed by trying to clone `https://github.com/you/personal-dotfiles.git`.

Fixed by making local path dependencies in `DOTTY_EXTENDS` resolve relative to the repo declaring them, updated the example overlay to extend `../personal-dotfiles`, and documented a concrete example install flow in `README.md`. Added Bats coverage for resolver behavior, doctor diagnostics, and installing the shipped layered examples. Also stabilized `test/operation_lock.bats` by using a real background process as the active lock owner after full-suite verification exposed the brittle test.

Verification: focused Bats files passed, full `./test/bats/bin/bats test/` passed, `git diff --check` passed, and a temp-home README-shaped flow passed against pushed `main` using `dotty install ./dotty/examples/work-dotfiles` plus `dotty trace ~/.config/git`.

Committed and pushed `86db518 fix: support repo-relative dotty dependencies` to `main`.
