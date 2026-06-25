---
id: 2026-06-25-run-outside-user-onboarding-pass-for-dotty
title: Run outside-user onboarding pass for dotty
state: complete
createdAt: 2026-06-25T00:39:16.997Z
updatedAt: 2026-06-25T20:13:12.069Z
---

Ran the outside-user onboarding pass via clean-room temp homes. Found that `examples/work-dotfiles` used a placeholder GitHub URL in `DOTTY_EXTENDS`, so installing the checked-in examples immediately failed by trying to clone `https://github.com/you/personal-dotfiles.git`.

Fixed by making local path dependencies in `DOTTY_EXTENDS` resolve relative to the repo declaring them, updated the example overlay to extend `../personal-dotfiles`, and documented a concrete example install flow in `README.md`. Added Bats coverage for resolver behavior, doctor diagnostics, and installing the shipped layered examples. Also stabilized `test/operation_lock.bats` by using a real background process as the active lock owner after full-suite verification exposed the brittle test.

Verification: focused Bats files passed, full `./test/bats/bin/bats test/` passed, `git diff --check` passed, and a temp-home README-shaped flow passed against pushed `main` using `dotty install ./dotty/examples/work-dotfiles` plus `dotty trace ~/.config/git`.

Committed and pushed `86db518 fix: support repo-relative dotty dependencies` to `main`.
