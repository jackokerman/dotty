---
id: 2026-06-24-design-dotty-one-shot-cleanup-tasks
title: Design dotty one-shot cleanup tasks
state: complete
createdAt: 2026-06-24T23:37:29.430Z
updatedAt: 2026-06-25T00:19:11.428Z
---

Implemented and verified Dotty one-shot cleanup tasks. The feature discovers .dotty/cleanups tasks, supports executable-file and directory/run.sh shapes, optional Bash metadata for environment/machine/description, install/update execution after linking and before hooks, dry-run reporting without execution or state writes, local done/failed receipts under $DOTTY_DIR/cleanups/<repo>/<id>, dotty cleanups status, doctor validation, zsh completions, README, AGENTS, and focused Bats tests. Verification passed: ./test/bats/bin/bats test/cleanups.bats, targeted adjacent suites, bash -n dotty, and full ./test/bats/bin/bats test/.
