---
id: 2026-06-25-polish-dotty-status-and-trace-output-from-feedback
title: Polish dotty status and trace output from feedback
state: inbox
createdAt: 2026-06-25T00:39:17.048Z
updatedAt: 2026-06-25T00:39:17.048Z
---

# Polish dotty status and trace output from feedback

## Plan

# Polish dotty status and trace output from feedback

## Source
Migrated from `ROADMAP.md` during roadmap cleanup.

## Why
`status` and `trace` are core debugging commands, but the right polish should come from real confusing cases rather than hypothetical ones.

## Outcome
`dotty status` and `dotty trace` are easier to use for concrete cases observed during onboarding or user support.

## Acceptance criteria
- Collect specific confusing `status` or `trace` cases from users or clean-room trials.
- Change output only where it addresses a concrete case.
- Keep `cmd_help()`, completions, README, and tests in sync if behavior changes.
- Add or update focused Bats coverage for the revised output.

## Dependency
Do this after onboarding or support produces concrete examples.
