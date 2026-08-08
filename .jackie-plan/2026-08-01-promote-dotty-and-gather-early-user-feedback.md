---
id: 2026-08-01-promote-dotty-and-gather-early-user-feedback
title: Promote dotty and gather early-user feedback
state: ready-to-implement
createdAt: 2026-08-01T00:37:32.369Z
updatedAt: 2026-08-08T00:44:19.790Z
---

# Promote dotty and gather early-user feedback

## Plan

## Objective

Put the released public project in front of its actual audience and turn observed onboarding or usage friction into evidence-backed issues or Jackie Plans.

## Scope

- Share the current release with a small number of coworkers or peers who maintain separate personal and work dotfiles.
- Ask them to follow the public install and layered-example path without live handholding, then collect the exact confusing step or command when something fails.
- Publish one concise community post centered on the personal-plus-work overlay problem rather than a generic feature list.
- After initial usage or feedback provides basic traction, submit dotty to the Tools section of `webpro/awesome-dotfiles` with a transparent maintainer-authored PR.
- Keep GitHub repository topics, release notes, examples, and issue forms current as feedback arrives.
- Use the audit-derived hypotheses below to recognize actionable feedback without treating inspiration from another dotfiles repository as product evidence by itself.

## Non-goals

- Do not add speculative features, paid promotion, broad cross-posting, testimonials without permission, or package-manager distribution before demand exists.
- Do not submit to `awesome-shell` until the project satisfies its published 50-star requirement.
- Do not copy repository-specific package management, macOS defaults, shell setup, or update orchestration into Dotty core when hooks or repo-defined commands already own those workflows.

## Recommended approach

Lead with the concrete problem: composing public personal dotfiles with private work or team overlays while keeping plain files and symlinks. Point users to the checked-in example and ask for an install diary rather than general impressions. File only reproducible product or documentation gaps. Treat requests for templates, secrets, or a broad ecosystem as possible evidence that another tool is a better fit.

Before package-manager distribution or broader branding work, reassess the active `ztlevi/dotty` name collision and decide whether consistent "Dotty — layered dotfiles" positioning is sufficient.

## Audit context and follow-up criteria

A 2026-08-07 comparison against Nick Nisi's public `nicknisi/dotfiles` repository at commit `f968e70cfeb5b7fcbd044eb734f33d59b452a30b` found one plausible core enhancement and several useful repo-level patterns. Nick's repository is an inspiration and implementation reference, not evidence of demand.

### Repo-command descriptions

Nick's `dot` dispatcher discovers executable `dot-*` commands from `PATH`, reads an optional `# Description:` comment, and displays descriptions in help. Dotty already has the safer chain-scoped equivalent: `.dotty/commands/`, `dotty commands`, `dotty run`, overlay resolution, doctor validation, and zsh completion. The existing completed plan `2026-06-25-improve-dotty-repo-command-discoverability` deliberately deferred command metadata because no user-facing discovery failure had been observed.

Reopen that decision only when at least one concrete workflow needs descriptions, such as:

- testers can find `dotty commands` but cannot tell what the listed commands do;
- a picker, completion UI, or help surface needs stable human-readable labels; or
- several managed repos accumulate enough commands that names and owning repos are insufficient.

If triggered, run a focused planning iteration before implementation. It must settle the metadata convention, whether descriptions are optional, output compatibility for `dotty commands`, safe parsing without executing command files, overlay behavior, zsh completion rendering, malformed metadata handling, and the required updates to `dotty`, `completions/_dotty`, `README.md`, examples, and `test/commands.bats`. Prefer one lightweight convention over sidecar files or a general plugin metadata system.

### Non-default XDG configuration roots

Nick maps a dedicated source `config/` directory to `${XDG_CONFIG_HOME:-$HOME/.config}`. Dotty intentionally mirrors `home/` into `$HOME`, which is simpler and already represents the default `~/.config` layout.

Do not plan arbitrary target roots without a report from a user whose `XDG_CONFIG_HOME` differs from `~/.config` and whose files cannot be represented cleanly through the current model. If that occurs, use a full planning iteration because the change would affect source layout, config schema, chain overlays, conflict handling, `add`, `link`, `files`, `trace`, `status`, backup restoration, uninstall, docs, examples, and tests. Avoid a one-off `config/` special case until the general target-root contract is understood.

### Repo-owned patterns, not core features

- App-generated fields in otherwise tracked JSON can be stripped with a tracked `.gitattributes` clean filter and idempotent filter registration in `.dotty/run.sh` or a repo-defined command. Add a public example only after a real Dotty user encounters this problem repeatedly.
- Homebrew, mise, Neovim, shell-plugin, and similar "update all" orchestration belongs in a repo-defined command because the selected tools and ordering are personal policy.
- macOS defaults, Homebrew bootstrap, terminfo installation, and personalized Git setup belong in repo hooks or commands.

### Explicitly rejected for the current roadmap

- Package-scoped link and unlink: full-chain relinking is cheap and preserves overlay correctness; partial unlink introduces transient state that the next update would reverse.
- Manual tar snapshot backups: Dotty already backs up displaced paths automatically and ties restoration to uninstall.
- Automatic `dot-*` discovery from global `PATH`: explicit chain-scoped commands avoid name collisions and accidental execution.
- A generic core `update all`: Dotty should not classify or own repo-specific package and plugin managers.

## Stopping points

- Stop a promotion channel if its rules exclude self-submission or the project does not meet its inclusion criteria.
- Pause feature work when feedback is preference-only or already belongs in repo hooks and conventions.
- Escalate the naming decision before publishing a package whose command or formula would collide.
- Do not turn any audit hypothesis into implementation work until its stated evidence threshold is met.

## Verification

- Record which public commands each tester ran and whether the clean onboarding path completed.
- Link every accepted follow-up to a concrete report, reproduction, or community requirement.
- For command discoverability feedback, record whether the user failed to find `dotty commands`, found it but needed descriptions, or needed a richer completion or picker surface; these imply different fixes.
- For XDG feedback, record the effective `XDG_CONFIG_HOME`, desired source layout, affected commands, and the exact current failure.
- Verify the Awesome Dotfiles PR follows the list's current formatting and contribution expectations.

## Agent handoff

### Resume state

The plan is approved and ready to implement. The Nick Nisi dotfiles-management audit is incorporated as evidence and routing guidance. No separate implementation plan was created because repo-command descriptions overlap the completed plan `2026-06-25-improve-dotty-repo-command-discoverability` and remain gated on concrete discoverability friction.

Execute the promotion and early-feedback objective as written. Use observed feedback to test the recorded triggers. If command descriptions become necessary, run a focused planning iteration covering metadata, output compatibility, parsing, overlays, completion, docs, and tests. If a non-default `XDG_CONFIG_HOME` failure appears, run a full planning iteration because arbitrary target roots affect most of Dotty's lifecycle. Keep clean filters, update orchestration, macOS setup, Homebrew, and terminfo repo-owned.

### Process notes

Compared Dotty with `nicknisi/dotfiles` at public commit `f968e70cfeb5b7fcbd044eb734f33d59b452a30b`. Explicitly rejected speculative package-scoped linking, manual snapshot backups, global `dot-*` discovery, and core `update all` behavior. The user approved this contract on 2026-08-07. No product files were changed.
