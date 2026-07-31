---
id: 2026-06-25-polish-dotty-status-and-trace-output-from-feedback
title: Polish dotty status and trace output from feedback
state: paused
createdAt: 2026-06-25T00:39:17.048Z
updatedAt: 2026-07-31T21:48:38.357Z
---

# Polish dotty status and trace output from feedback

## Plan

## Objective

Improve `dotty status` or `dotty trace` only for a concrete confusing output case observed in onboarding or support.

## Current state

The outside-user onboarding pass completed without identifying a status- or trace-output comprehension problem. The current audit also found no captured reproduction in the backlog or recent history. Changing labels or output structure now would be speculative presentation churn.

## Resume trigger

Resume when there is a specific command, fixture, expected interpretation, and confusing actual output from a user or clean-room trial.

## Implementation contract when resumed

- reproduce the case in a focused Bats fixture first;
- change the smallest output boundary that resolves the confusion;
- preserve script-facing behavior unless a documented contract change is intentional;
- keep help, completions, README, and tests aligned when their text or command contract is affected.
