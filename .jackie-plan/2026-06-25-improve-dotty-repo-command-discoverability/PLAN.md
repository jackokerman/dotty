---
id: 2026-06-25-improve-dotty-repo-command-discoverability
title: Improve Dotty repo-command discoverability
state: inbox
createdAt: 2026-06-25T03:23:22.317Z
updatedAt: 2026-06-25T03:23:22.317Z
sourcePlan: 2026-06-25-build-preferred-personal-tooling-stack
sourceRepo: /Users/jackokerman/dotfiles
sourcePath: .
---

# Improve Dotty repo-command discoverability

## Plan

# Improve Dotty repo-command discoverability

Dotty already ships zsh completions for repo-defined commands: `dotty run <TAB>` calls `dotty commands` and completes command names from the active chain. The commands are not sourced and are not installed into `bin`; `dotty run <name>` dispatches executable files from `.dotty/commands/` with Dotty context env vars.

Follow up only if the current discoverability still feels weak after using it:

- Verify `dotty run <TAB>` works on personal and work machines after `dotty update`; use `reload-completions` if the shell cache is stale.
- Consider adding richer descriptions for repo-defined commands, either by extending `dotty commands` output or supporting optional command metadata.
- Consider documenting `dotty commands` and `dotty run <TAB>` more prominently in dotfiles new-machine/daily-use docs if it remains easy to forget.
- Avoid putting repo commands directly on `PATH` unless a command is genuinely a daily CLI; keep one-off maintenance commands behind `dotty run`.
