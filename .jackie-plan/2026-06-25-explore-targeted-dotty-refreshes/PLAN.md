---
id: 2026-06-25-explore-targeted-dotty-refreshes
title: Explore targeted Dotty refreshes
state: ready-to-implement
createdAt: 2026-06-25T18:28:43.071Z
updatedAt: 2026-06-30T01:16:14.296Z
---

# Explore targeted Dotty refreshes

## Plan

# Objective

Document Dotty's existing refresh levels so future users and agents can choose the smallest honest command without adding repo-specific path heuristics to generic Dotty.

# Current contract

Dotty already has distinct refresh behaviors:

- `dotty update [name]` pulls dotty and one or more registered repos, then re-runs the full symlink, cleanup, and hook cycle.
- `dotty link [name]` re-creates symlinks and cleans orphan symlinks without pulling repos, running cleanups, or running hooks.
- `dotty self-update` updates only the Dotty tool itself.

The operation lock is the safety boundary for mutating commands. It prevents overlapping `install`, `update`, `link`, `uninstall`, and `self-update` operations from mutating shared Dotty or home-directory state at the same time.

# User problem

The safe default after tracked config changes is often `dotty update`, but some edits do not need the full update cycle. A broad update pulls repos, relinks the chain, runs cleanups, and runs hooks. Operation locking prevents unsafe overlap, but it does not avoid unnecessary broad work.

# Planning conclusion

Make this a docs-only pass for Dotty core.

Do not add a `dotty refresh-plan` command in this slice. The command would mostly print static guidance, and adding command surface before repeated use proves it is needed would make Dotty less simple without much benefit.

Do not add automatic changed-path classification to generic Dotty. Dotty cannot reliably know whether a changed path affects generated config, hooks, machine-local workflows, downstream tooling, or external control surfaces without repo-specific rules.

Repo-specific refresh strategies should live downstream, either in managed repo docs, repo-defined `dotty run` commands, or separate tooling that owns the relevant domain.

# Generic refresh ladder to document

- No Dotty command needed: changes that do not affect live linked files, generated runtime config, hooks, cleanups, or installed Dotty state.
- `dotty link`: changed files under linked `home/` trees or environment overlays when only symlink/orphan refresh is needed.
- `dotty update <name>`: one registered repo needs pulling, followed by the full chain link, cleanup, and hook cycle.
- `dotty update`: the whole active chain should be pulled, relinked, cleaned up, and re-hooked.
- `dotty self-update`: only the Dotty tool itself should be updated.

# Potential first slice

Update README/help docs to make the refresh ladder explicit and to warn that generic Dotty does not classify repo-specific changed paths.

Keep the implementation small:

- Add a short refresh guidance section to `README.md` near the command docs.
- Update `cmd_help()` only if a concise note improves command selection without making help noisy.
- Do not change completions unless a command description changes.
- Do not add new commands or queueing behavior.

# Deferred follow-ups

- Downstream repos may define their own refresh/sync strategy using docs, repo-defined `dotty run` commands, or domain-specific tooling.
- Development-checkout sync for local tool repos belongs in the downstream repo that owns that workflow, not in generic Dotty, unless Dotty later needs a minimal primitive to support it.
- Queueing/coalescing update requests should remain out of scope until there is observed redundant-update pain after operation locking.

# Acceptance criteria

- README/help guidance makes the existing refresh ladder explicit.
- The docs clearly say generic Dotty does not classify repo-specific changed paths.
- The operation lock remains the safety boundary for mutating commands.
- No new command, queue, config mechanism, or automatic classifier is added in this slice.
- The docs keep Dotty open-source and generic; managed repo-specific heuristics stay downstream.
- Verification covers the documentation/edit scope, with no behavior tests required unless command text changes in a test-covered way.
