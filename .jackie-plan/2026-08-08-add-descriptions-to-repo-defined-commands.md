---
id: 2026-08-08-add-descriptions-to-repo-defined-commands
title: Add descriptions to repo-defined commands
state: ready-to-implement
priority: high
createdAt: 2026-08-08T00:49:16.958Z
updatedAt: 2026-08-08T00:50:35.739Z
sourcePlan: 2026-06-25-improve-dotty-repo-command-discoverability
---

# Add descriptions to repo-defined commands

## Plan

## Objective

Make repo-defined commands self-describing in `dotty commands` and `dotty run` zsh completion so users can discover what a command does without opening its executable file.

## Motivation and evidence

A 2026-08-07 audit of Nick Nisi's public `nicknisi/dotfiles` repository at commit `f968e70cfeb5b7fcbd044eb734f33d59b452a30b` found a small discoverability feature worth adopting: executable `dot-*` commands may declare a `# Description:` comment that is displayed in help.

Dotty already has the stronger command boundary: `.dotty/commands/` is chain-scoped, later repos override earlier commands, `dotty commands` reports the winning command and owning repo, `dotty run` executes only the resolved command, `dotty doctor` validates command files, and zsh completion obtains names from `dotty commands`. The missing piece is optional human-readable metadata on that existing surface.

This intentionally supersedes the no-change decision in completed plan `2026-06-25-improve-dotty-repo-command-discoverability`. The user has chosen to add the feature before sharing or promoting Dotty.

## User-facing contract

- A repo command may declare one optional single-line description using an exact comment of the form `# Description: Human-readable text` in the executable command file.
- Dotty reads command metadata as text. It must never source or execute a command while listing commands or generating completion candidates.
- The resolved command's description follows normal overlay semantics: when a later repo replaces a command, its file and description replace the earlier definition together.
- `dotty commands` continues to sort by command name and report the command name and owning repo. When a non-empty description exists, it also displays that description as a third tab-separated field.
- Commands without a description remain valid and keep useful output. Do not require metadata and do not make `dotty doctor` warn or fail when it is absent.
- `dotty run <TAB>` continues to complete stable command names and shows the optional description as completion help when the shell supports it. Completion must still work for commands without descriptions.

## Metadata parsing

- Read the first exact `# Description:` line from the winning executable file and ignore later matches.
- Strip the marker and surrounding horizontal whitespace.
- Treat an empty value as no description.
- Keep the value single-line and normalize literal tab characters before emitting tab-separated command records.
- Do not add sidecar metadata files, configuration variables, multiline descriptions, localization, or a general plugin manifest.
- Keep parsing portable across the GNU and BSD userlands supported by Dotty.

## Implementation scope

- Add a private helper in `dotty` that safely extracts the optional description from a command file.
- Extend resolved repo-command records to carry the winning description alongside name, repo, path, and executable state.
- Update `cmd_commands()` to emit `name`, owning repo, and the optional description without changing command resolution or execution.
- Update `completions/_dotty` to parse tab-separated command output without splitting descriptions on spaces and to present descriptions through the native zsh completion annotation mechanism.
- Update `cmd_help()` and the repo-command sections of `README.md` to document the metadata convention and output.
- Add a description to the checked-in repo-command example so the public contract is concrete.
- Update `.github/ISSUE_TEMPLATE/` only if an existing form describes repo-command structure or asks users to reproduce command-discovery behavior; do not add unrelated issue-form content.

## Tests

Extend `test/commands.bats` to cover:

- a described command appears with name, winning repo, and description;
- an undescribed command retains valid output;
- a later overlay replaces both an earlier command and its description;
- only the first exact description marker is used;
- empty descriptions behave as absent;
- description lookup does not execute or source the command;
- spaces and literal tabs cannot corrupt record parsing or completion input;
- existing non-executable shadowing and `dotty run` behavior remain unchanged.

Validate the completion file with `zsh -n completions/_dotty` and add the smallest practical completion-focused check for description annotations if the existing test harness can exercise it without introducing a new framework.

## Non-goals

- Do not discover commands from global `PATH` or support Nick's automatic `dot-*` fallback dispatch.
- Do not add aliases, argument schemas, categories, ordering metadata, hidden commands, per-command help execution, or machine-readable JSON output.
- Do not redesign `dotty commands`, `dotty run`, command resolution, or doctor validation beyond carrying optional descriptions.
- Do not add descriptions to built-in commands through this metadata path; their help and completion descriptions remain owned by `cmd_help()` and `completions/_dotty`.

## Stopping points and exception criteria

- Stop and revise the plan if adding a third field would break a documented external output contract or an in-repo consumer that cannot be updated atomically.
- Stop before sourcing command files or executing them to obtain metadata.
- If native zsh annotations require escaping that cannot be made reliable with the tab-separated output, keep stable name completion and document the limitation rather than adding a second metadata transport.
- If the implementation reveals a need for metadata beyond a single description, finish this narrow feature and capture broader command manifests separately with concrete evidence.

## Verification

1. Run `./test/bats/bin/bats test/commands.bats` while iterating.
2. Run `bash -n dotty` and `zsh -n completions/_dotty`.
3. Exercise a temporary two-repo chain with described, undescribed, and overridden commands; inspect `dotty commands` and zsh completion output.
4. Run `./dotty doctor` against the temporary chain and confirm missing descriptions remain valid.
5. Run the full `./test/bats/bin/bats test/` suite.
6. Run `git diff --check` and verify `cmd_help()`, completions, README, examples, and relevant issue forms remain aligned.

## Follow-ups

Do not block this feature on first-class `XDG_CONFIG_HOME` target roots or generic lifecycle orchestration. Those are separate adoption decisions and were not recommended as current Dotty core work by the audit.

## Agent handoff

### Resume state

The plan is approved, high priority, and ready to implement. It is the explicit prerequisite to coworker sharing and public promotion and supersedes the earlier no-change decision about command metadata.

Implement only optional single-line `# Description:` metadata on the existing chain-scoped repo-command surface. Preserve command resolution and execution. Carry the winning description into `dotty commands` and zsh completion without sourcing command files. Complete the focused and full verification in the contract before marking the plan complete.

### Process notes

The plan was split from promotion after the user clarified sequencing and approved on 2026-08-07. No separate core plans were created for clean filters, update orchestration, XDG target roots, package-scoped linking, manual snapshots, or global command discovery because the audit did not justify adopting them into Dotty core. Promotion remains in `inbox` until this feature is implemented and released.
