---
id: 2026-08-01-add-a-concise-terminal-demo-to-the-dotty-readme
title: Add a concise terminal demo to the dotty README
state: inbox
createdAt: 2026-08-01T00:37:32.069Z
updatedAt: 2026-08-01T00:37:32.069Z
---

# Add a concise terminal demo to the dotty README

## Plan

## Objective

Add a short, authentic terminal recording near the top of `README.md` that makes dotty's layered-repo value understandable before readers reach the command reference.

## Scope

- Record the checked-in personal/work example flow in a clean temporary home.
- Show `dotty install`, `dotty status`, and `dotty trace ~/.config/git` in roughly 30–60 seconds.
- Store or link the smallest durable asset format that renders reliably on GitHub.
- Add a concise caption and accessible fallback text to `README.md`.

## Non-goals

- Do not add product behavior, sample-only CLI output, decorative branding, or a long narrated tutorial.
- Do not expose personal paths, hostnames, private repositories, credentials, or machine-specific configuration.

## Recommended approach

Use the public install and checked-in `examples/work-dotfiles` path exactly as documented. Record at a readable terminal size with a fresh temporary `HOME`, trim idle time, and keep the focus on the resolved chain and provenance output. Prefer a repository-owned asset only if its size is reasonable; otherwise use a stable terminal-recording host with a static preview.

## Stopping points

- Stop and revise the flow if the public commands do not work unchanged in a clean environment.
- Stop before adding a large binary when a smaller encoding or hosted recording would preserve the same value.

## Verification

- Replay the documented commands in a fresh temporary home.
- Confirm the rendered README preview loads the asset and remains useful when the asset does not autoplay.
- Inspect every visible frame for private or machine-specific data.
- Run `git diff --check` and the smallest documentation checks available.
