# AGENTS.md

## Scope

- Dotty is open source. Never hardcode specific user directories, personal repo names, or machine-specific paths in code, tests, or docs.
- Discover the current local setup at runtime with `./dotty status` or `~/.dotty/registry`.

## Project Map

- `dotty` is the main bash entry point. It contains logging, registry, chain resolution, environment detection, symlinking, command handlers, and main dispatch.
- `install.sh` bootstraps dotty itself.
- `lib/utils.sh` contains shared shell helpers used by hooks and related tooling.
- `hooks/pre-commit` is the guard hook template installed by `dotty guard`; it delegates to `dotty guard-check` at commit time.
- `completions/_dotty` contains zsh completions.
- `.github/ISSUE_TEMPLATE/` contains the GitHub issue forms for bug reports and feature requests.
- `examples/` contains contributor-facing sample dotfiles layouts referenced from the docs and issue forms.
- `.dotty/commands/` in managed repos is the source of repo-defined `dotty run` commands.
- `.dotty/cleanups/` in managed repos is the source of one-shot cleanup tasks that run during `install` and `update`.
- `.dotty/managed-checkouts.tsv` in managed repos is the source of editable Git checkouts that `dotty checkouts`, `install`, and `update` may clone or fast-forward.
- `test/*.bats` is the repo's behavior test suite.

## Architecture

- Dotty manages chains of dotfiles repos with later repos overriding earlier repos.
- Managed repo discovery and compatibility live in the config, hook lookup, repo-command lookup, cleanup lookup, and managed-checkout manifest helpers; keep `.dotty/config`, optional `.dotty/run.sh`, optional `.dotty/commands/`, optional `.dotty/cleanups/`, optional `.dotty/managed-checkouts.tsv`, and migration behavior aligned with the tests and README.
- `home/` is symlinked into `$HOME`; `$ENV/home/` overlays are applied when an environment is detected.
- `dotty install` resolves the chain, registers repos, syncs managed checkouts, links files, applies overlays, and runs hooks.
- Mutating Dotty operations take a per-machine lock under `~/.dotty/operation.lock`; keep `install`, `update`, `checkouts`, `link`, `uninstall`, and `self-update` serialization aligned with `test/operation_lock.bats`.
- Managed checkouts run during `install` and `update` after chain repos are pulled and before repo files, cleanups, or hooks are processed. Keep lifecycle ordering aligned with `test/managed_checkouts.bats` and `test/update_parallel.bats`.
- Pending one-shot cleanups run after linking and before hooks, with local completion state under `~/.dotty/cleanups/`.
- `dotty link` refreshes symlinks only. It does not pull repos or run hooks.
- `dotty run` resolves repo-defined commands from the active chain and executes them from the defining repo root.
- Directory conflicts are merged by exploding directory symlinks into real directories with child symlinks rather than replacing the whole directory.
- Hook environment variables are `DOTTY_REPO_DIR`, `DOTTY_ENV`, and `DOTTY_COMMAND`.
- Runtime state lives under `~/.dotty/`, especially `registry`, `repos/`, `backups/`, `bin/dotty`, `.needs-reload`, and `operation.lock`.

## Bash Expectations

- Preserve `set -euo pipefail`.
- Keep the existing naming conventions: `_private` helpers, `cmd_*` command handlers, and `registry_*` registry helpers.
- Maintain GNU/BSD portability, especially for `sed` and other small shell utilities.
- Add ShellCheck suppressions only when the shell pattern is intentional.

## Validation

- First run on a fresh clone: `git submodule update --init`.
- Standard validation: `./test/bats/bin/bats test/`.
- While iterating, run the smallest relevant bats file in addition to the full suite when practical.
- For risky symlink or chain-resolution changes, test with a temporary repo before checking a real dotfiles setup.
- For shared-state locking or serialization changes, also run a real mutating command smoke test and assert the lock or state artifact is cleaned up afterward.
- When a change affects live linking or hooks, use `./dotty status` or `~/.dotty/registry` to discover the local chain, then run the smallest real command needed to validate it.

## Keep Docs In Sync

When dotty behavior changes, update the same change set:

- `cmd_help()` in `dotty`
- `completions/_dotty`
- `README.md`
- `.github/ISSUE_TEMPLATE/`
- `examples/`
- Downstream repo docs that describe dotty behavior, including `AGENTS.md` files and compatibility `CLAUDE.md` symlinks in managed repos
- Downstream hooks, shell config, install scripts, and other files that reference dotty env vars or `$DOTTY_LIB`
