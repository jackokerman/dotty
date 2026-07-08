---
id: 2026-07-08-preserve-dotty-registry-order-on-register
title: Preserve Dotty registry order on register
state: inbox
createdAt: 2026-07-08T22:52:58.405Z
updatedAt: 2026-07-08T22:54:01.979Z
---

# Preserve Dotty registry order on register

## Plan

Problem:
`dotty register <path> <name>` updates an existing registry entry by removing the old row and appending the replacement at the end. When replacing a registered base repo checkout path with an existing visible checkout, this can move the base repo after a later overlay in `~/.dotty/registry`.

Observed impact:
- The registry briefly became overlay-first even though the resolved chain was still conceptually base-to-overlay.
- `dotty status` displayed confusing link counts, with the base repo shown as mostly overridden until the registry file was manually reordered and `dotty update` relinked the base files.
- This makes a reasonable one-checkout migration feel unsafe and invites manual registry editing.

Desired behavior:
Updating an existing registry entry should preserve that entry's original line position. Adding a new repo can still append. Registry order is part of Dotty's user-visible layering model and should not change as a side effect of replacing a path for an existing repo name.

Suggested implementation:
Change `registry_set` so an update rewrites the matching `name=` line in place instead of filtering it out and appending. Keep behavior for new names unchanged.

Verification:
Add or update focused tests that cover:

- `dotty register /new/path dotfiles` preserves `dotfiles` position when `dotfiles` already exists before an overlay row.
- New registrations still append.
- `dotty status` or a registry-order fixture continues to present base before overlay after path replacement.

## Agent handoff

This follow-up came from consolidating a duplicate base dotfiles checkout on one machine. The local repair was completed manually: the registry path was changed to the visible checkout, stale cleanup state was repaired, the hidden clone was removed, and `dotty update` passed afterward. The durable Dotty issue is only the order-preservation behavior in `register` / `registry_set`.
