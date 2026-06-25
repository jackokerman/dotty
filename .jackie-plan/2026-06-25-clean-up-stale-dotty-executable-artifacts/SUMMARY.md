---
id: 2026-06-25-clean-up-stale-dotty-executable-artifacts
title: Clean up stale dotty executable artifacts
state: inbox
createdAt: 2026-06-25T16:36:05.006Z
updatedAt: 2026-06-25T16:36:05.006Z
---

# Summary

Related prior plan: `2026-06-24-design-dotty-one-shot-cleanup-tasks`.

A stale dotty executable artifact was observed while investigating cleanup-task behavior.

Observed shape:
- `dotty` on `PATH` resolves through `~/.dotty/bin/dotty`.
- `~/.dotty/bin/dotty` may point at a development checkout's `dotty` executable and report the current version.
- A stale executable can still exist at `~/.dotty/dotty`.
- Running the stale executable can fail with `~/.dotty/lib/utils.sh: No such file or directory` when its adjacent support files no longer exist.

This is not necessarily on `PATH`, but it is confusing and can lead agents or humans to inspect or invoke the wrong implementation.

Investigate and fix install/self-update hygiene:
- Decide whether `~/.dotty/dotty` should exist when `~/.dotty/bin/dotty` points at a development checkout.
- If it should not exist, add a guarded cleanup or migration that removes or replaces it only when it is clearly stale and not the active executable.
- If it should exist, repair the expected adjacent `lib/` layout or update installer docs to avoid broken partial installs.
- Add a `dotty doctor` check if helpful so stale executable artifacts are visible.

Acceptance criteria:
- `command -v dotty`, installer docs, and actual files under `~/.dotty/` tell one coherent story.
- Running obvious dotty executable paths does not fail due to missing adjacent support files.
- Any cleanup is guarded so it does not delete a real active dotty install.
