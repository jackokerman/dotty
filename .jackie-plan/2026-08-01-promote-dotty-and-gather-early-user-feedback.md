---
id: 2026-08-01-promote-dotty-and-gather-early-user-feedback
title: Promote dotty and gather early-user feedback
state: inbox
createdAt: 2026-08-01T00:37:32.369Z
updatedAt: 2026-08-08T00:49:35.521Z
---

# Promote dotty and gather early-user feedback

## Plan

## Objective

Put the released public project in front of its actual audience and turn observed onboarding or usage friction into evidence-backed issues or Jackie Plans.

## Dependency

Complete `2026-08-08-add-descriptions-to-repo-defined-commands` before beginning coworker sharing or public promotion. This ordering reflects the user's decision to incorporate the worthwhile core feature from the Nick Nisi dotfiles audit before asking new users to evaluate Dotty.

The dependency is narrow. Repo-specific clean filters, package-manager orchestration, macOS setup, partial linking, snapshot backups, global `dot-*` discovery, and first-class non-default XDG target roots are not promotion prerequisites.

## Scope

- After the dependency is complete, share the current release with a small number of coworkers or peers who maintain separate personal and work dotfiles.
- Ask them to follow the public install and layered-example path without live handholding, then collect the exact confusing step or command when something fails.
- Publish one concise community post centered on the personal-plus-work overlay problem rather than a generic feature list.
- After initial usage or feedback provides basic traction, submit Dotty to the Tools section of `webpro/awesome-dotfiles` with a transparent maintainer-authored PR.
- Keep GitHub repository topics, release notes, examples, and issue forms current as feedback arrives.

## Non-goals

- Do not add speculative features, paid promotion, broad cross-posting, testimonials without permission, or package-manager distribution before demand exists.
- Do not submit to `awesome-shell` until the project satisfies its published 50-star requirement.
- Do not copy repository-specific package management, macOS defaults, shell setup, or update orchestration into Dotty core when hooks or repo-defined commands already own those workflows.

## Recommended approach

First implement and release repo-command descriptions through `2026-08-08-add-descriptions-to-repo-defined-commands`. Then lead promotion with the concrete problem: composing public personal dotfiles with private work or team overlays while keeping plain files and symlinks. Point users to the checked-in example and ask for an install diary rather than general impressions. File only reproducible product or documentation gaps. Treat requests for templates, secrets, or a broad ecosystem as possible evidence that another tool is a better fit.

Before package-manager distribution or broader branding work, reassess the active `ztlevi/dotty` name collision and decide whether consistent "Dotty — layered dotfiles" positioning is sufficient.

## Stopping points

- Do not begin sharing or promotion while `2026-08-08-add-descriptions-to-repo-defined-commands` remains unfinished.
- Stop a promotion channel if its rules exclude self-submission or the project does not meet its inclusion criteria.
- Pause feature work when feedback is preference-only or already belongs in repo hooks and conventions.
- Escalate the naming decision before publishing a package whose command or formula would collide.

## Verification

- Confirm `2026-08-08-add-descriptions-to-repo-defined-commands` is complete and its implementation is present on the default branch before contacting testers.
- Record which public commands each tester ran and whether the clean onboarding path completed.
- Link every accepted follow-up to a concrete report, reproduction, or community requirement.
- Verify the Awesome Dotfiles PR follows the list's current formatting and contribution expectations.

## Agent handoff

### Resume state

Promotion is intentionally back in `inbox` and depends on completion of high-priority plan `2026-08-08-add-descriptions-to-repo-defined-commands`. Do not begin coworker sharing or public promotion until that feature is implemented, verified, committed, and available on the default branch.

After the dependency completes, execute the promotion and early-feedback contract as written. Keep repo-owned management patterns and unsupported audit ideas out of Dotty core unless later user evidence warrants separate planning.

### Process notes

The Nick Nisi audit was moved out of this plan into a dedicated feature plan after the user clarified that worthwhile audit features should ship before promotion. This plan now owns only the later sharing and feedback phase.
