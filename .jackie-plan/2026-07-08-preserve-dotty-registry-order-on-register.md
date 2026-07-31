---
id: 2026-07-08-preserve-dotty-registry-order-on-register
title: Preserve Dotty registry order on register
state: ready-to-implement
priority: high
createdAt: 2026-07-08T22:52:58.405Z
updatedAt: 2026-07-31T21:52:12.277Z
---

# Preserve Dotty registry order on register

## Plan

## Objective

Preserve registry order when `dotty register <path> <name>` updates an existing name. Registry order is user-visible layering state and must not change as a side effect of replacing a checkout path.

## Verified current behavior

`registry_set` currently removes every matching `name=` row, appends the replacement to a temporary file, and moves that file over the registry. Updating a base entry therefore moves it after later overlays. `test/registry.bats` verifies that other entries survive, but it does not assert their order.

The bug was observed during a checkout-path migration: the registry became overlay-first, `dotty status` showed confusing override counts, and manual registry reordering plus `dotty update` was required to restore the intended layout.

## Implementation contract

Change only `registry_set` and focused registry tests.

- Rewrite the registry in one pass to the existing temporary file.
- Compare the field before the first `=` with the requested name using Bash string equality, not a regular expression.
- Write the replacement at the first matching row's position.
- Skip later duplicate rows so updates retain the existing deduplication behavior.
- Append the new row only when no existing row matched.
- Keep the existing atomic temporary-file-and-`mv` shape and the behavior of `registry_get`, `registry_remove`, and `registry_names` unchanged.

Do not add a registry-order command, migration, compatibility mode, or automatic relinking. Existing registries are not reordered; this fix prevents future path updates from changing order.

## Verification

Add focused coverage in `test/registry.bats` for:

- updating the first of multiple entries preserves exact line order;
- updating a middle entry preserves exact line order;
- duplicate matching rows collapse to one replacement at the first match;
- a new registration still appends.

Run:

- `./test/bats/bin/bats test/registry.bats`
- `bash -n dotty`
- `./test/bats/bin/bats test/`

No README, help, or completion change is needed because this restores the existing layering contract without changing command syntax.

## Stopping point

Stop after the focused test passes if the implementation reveals that registry order is intentionally derived elsewhere or that replacing an entry must preserve duplicate rows. Otherwise complete the scoped fix and full-suite verification in one pass.

## Agent handoff

This follow-up came from consolidating a duplicate base dotfiles checkout on one machine. The local repair was completed manually: the registry path was changed to the visible checkout, stale cleanup state was repaired, the hidden clone was removed, and `dotty update` passed afterward. The durable Dotty issue is only the order-preservation behavior in `register` / `registry_set`.
