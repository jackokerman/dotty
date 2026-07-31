---
id: 2026-06-25-clean-up-stale-dotty-executable-artifacts
title: Clean up stale dotty executable artifacts
state: complete
createdAt: 2026-06-25T16:36:05.006Z
updatedAt: 2026-07-31T21:48:38.190Z
---

# Clean up stale dotty executable artifacts

## Plan

## Outcome

Audit completed without a Dotty core change.

The live machine reproduced the reported hybrid state:

- `command -v dotty` resolved through `~/.dotty/bin/dotty` to a development checkout and reported version `0.3.0`.
- `~/.dotty/dotty` was an inactive old regular file.
- Running that old file failed because the adjacent `~/.dotty/lib/utils.sh` did not exist.

The public installer already has one coherent contract: it installs the tracked tree at `DOTTY_DIR`, links `DOTTY_DIR/bin/dotty` to `DOTTY_DIR/dotty`, and installs adjacent `lib` and hook paths. The reproduced hybrid layout was machine-local development state, not a layout the current installer creates. Adding installer fallback behavior or a permanent doctor check would preserve an obsolete local path without a current product requirement.

The inactive `~/.dotty/dotty` file was removed only after resolving the active executable and confirming it targeted a different path. The active `dotty version` and `dotty status` commands continued to work.

## Decision

Keep the installer contract unchanged. Treat future hybrid development-checkout cleanup as guarded machine-local maintenance at the source that creates the development link. Reopen this only if the current public installer can reproduce a broken adjacent-support layout.
