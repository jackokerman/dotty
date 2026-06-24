---
id: 2026-06-24-design-dotty-one-shot-cleanup-tasks
title: Design dotty one-shot cleanup tasks
state: ready-to-implement
createdAt: 2026-06-24T23:37:29.430Z
updatedAt: 2026-06-24T23:51:33.729Z
---

Plan lives in dotty repo-local `.jackie-plan` and is ready to implement. It defines first-class `.dotty/cleanups/` tasks: run pending applicable cleanups during `install`/`update` after linking and before hooks; store local completion under `$DOTTY_DIR/cleanups/<repo>/<id>`; key reruns by explicit cleanup id rather than file content; add `dotty cleanups` status and doctor validation; keep cross-machine shared receipts out of V1. The separate Jackie Plan routing/steering follow-up was captured in the Jackie Plan repo as `2026-06-24-clarify-repo-local-planning-setup-for-new-repos`.
