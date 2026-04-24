# Roadmap

Dotty is aiming for a polished v1 for power users who want layered personal, work, and machine-specific dotfiles without moving to a template-heavy tool. The backlog below is ordered on purpose.

The default next task is the top unchecked item under `Now`, then `Next`, then `Later`. If a behavior change lands, keep `README.md`, `cmd_help()`, `completions/_dotty`, and the relevant tests in sync in the same change set.

## Now

- [x] Create `ROADMAP.md`. Why: future sessions need a stable source of truth instead of relying on prompt history. Done when: the repo has an ordered backlog with explicit acceptance criteria.
- [x] Rewrite the top of `README.md`. Why: the current README is thorough, but the value prop is not sharp enough for a first-time outside reader. Done when: the first sections explain who `dotty` is for, what problem it solves, and why repo chains matter.
- [x] Add an honest comparison section to `README.md`. Why: adoption gets easier when readers can quickly tell whether `dotty` fits better than `chezmoi`, `yadm`, `Stow`, or `Dotbot`. Done when: the README positions `dotty` around layered repos and override semantics, not templates or secrets.
- [x] Add OSS trust files. Why: people are less likely to adopt or contribute without basic repo hygiene. Done when: the repo has `LICENSE`, `CONTRIBUTING.md`, and `RELEASING.md`.
- [x] Add CI on macOS and Linux. Why: public trust is higher when basic compatibility is machine-verified. Done when: GitHub Actions runs the bats suite on `ubuntu-latest` and `macos-latest`.
- [x] Add a clean-home install smoke test to CI. Why: onboarding is the first public failure mode, not deep internals. Done when: CI exercises install, link, status, doctor, trace, check, and `shell-init` from a temporary home directory.
- [x] Add `dotty doctor`. Why: outside users need a read-only way to validate registry state and repo health before debugging symlink behavior manually. Done when: `dotty doctor` checks registered paths, config discovery, non-mutating chain resolution, environment declarations, hooks, and repo-defined commands, and its behavior is documented and tested.
- [x] Add one strong layered example to `README.md`. Why: the product makes the most sense when readers see a concrete personal-plus-work setup. Done when: the README includes a copy-pasteable example and shows the resulting files under `$HOME`.

## Next

- [x] Revisit installer ergonomics for bash and zsh. Why: the installer needed to stop assuming bash for PATH setup and stop leaving zsh users to finish the last step themselves. Done when: first-run shell setup is explicit and unsurprising for both shells.
- [ ] Cut the first tagged release for the public-ready baseline. Why: sharing a moving `main` branch is weaker than sharing a named release. Done when: `DOTTY_VERSION` is bumped, a tag is pushed, and release notes summarize the public baseline.
- [ ] Tighten contributor ergonomics around examples and issue intake. Why: once the tool is shared, lightweight issue templates and a small example repo or fixture may pay off. Done when: public contributors have an obvious path to report bugs or propose changes without guessing project norms.

## Later

- [ ] Revisit whether `dotty init` is worth adding. Why: it could shorten setup for new users, but it is only worth the complexity if docs and the installer still feel too manual. Done when: the decision is based on actual onboarding friction instead of speculation.
- [ ] Polish `status` and `trace` output based on real user feedback. Why: the right improvements will be obvious only after a few outside users try to debug their own setups. Done when: changes address concrete confusing cases, not hypothetical ones.

## Not now

- [ ] Add a template DSL. Why: that would push dotty toward a different class of tool and blur its current value prop. Done when: this stays out of scope until real users ask for it repeatedly.
- [ ] Add built-in secrets management or encryption. Why: other tools already specialize here, and the current goal is layered dotfiles composition. Done when: this remains deferred unless the product direction changes.
- [ ] Add built-in JSON merge abstractions or package-manager integrations. Why: hooks already cover these workflows, and hardcoding policy too early would add surface area without enough evidence. Done when: these stay as hook-level patterns for now.
