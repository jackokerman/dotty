# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository. Dotty is open source, so this file must never reference specific user directories, personal repo names, or machine-specific paths. Use `dotty status` and `~/.dotty/registry` to discover the user's setup at runtime instead.

## Project overview

Dotty is a bash dotfiles manager with overlay semantics. It manages chains of dotfiles repositories where later repos override earlier ones, with support for environment-specific overlays, directory merging, and git-based dependency resolution.

The entire tool is a single bash script (`dotty`, ~830 lines) plus an installer (`install.sh`). There is no build system and no external dependencies beyond bash and git. Tests use [bats-core](https://github.com/bats-core/bats-core) (included as a git submodule at `test/bats/`).

## Architecture

The `dotty` script is structured as a monolithic bash program with procedural sections:

1. **Logging** (color-coded output helpers: `title`, `info`, `success`, `warning`, `die`)
2. **Registry** (`registry_*` functions manage a flat `name=path` file at `~/.dotty/registry`)
3. **Config reading** (sources `.dotty/config` from each repo via `_find_config`/`_has_config` helpers)
4. **Chain resolution** (recursive dependency resolution with cycle detection via `resolve_chain`)
5. **Environment detection** (evaluates `DOTTY_ENV_DETECT` from first repo that defines it)
6. **Symlink management** (`create_symlinks_for`, `_link_item`, `_explode_dir_symlink` handle recursive directory merging)
7. **Commands** (`cmd_install`, `cmd_update`, `cmd_add`, `cmd_link`, `cmd_status`, etc.)
8. **Main dispatch** (entry point routes to command functions)

**Key flow (`install`):** resolve source → resolve dependency chain → register all repos → for each repo: pull, symlink `home/`, apply environment overlay, run hook (`.dotty/run.sh` or `dotty-run.sh`).

**Hook environment variables:** `DOTTY_REPO_DIR` (repo path), `DOTTY_ENV` (detected environment), `DOTTY_COMMAND` (`install` or `update`). Hooks are skipped during `link`.

**Directory merging:** when linking directories, dotty recurses into them and symlinks individual files rather than replacing the whole directory. If a directory symlink already points elsewhere, it "explodes" it into a real directory with child symlinks to preserve both sources.

**Guard:** `dotty guard`/`unguard` install a pre-commit hook (`hooks/pre-commit`) into a git repo's `.git/hooks/`. The hook reads `DOTTY_GUARD_PATTERNS` (newline-separated regexes) at commit time and blocks commits containing matches. The hook is a standalone script, not generated or templated.

## Bash conventions

- `set -euo pipefail` at the top
- Private functions prefixed with `_` (e.g., `_link_item`, `_resolving`)
- `cmd_` prefix for command implementations
- `registry_` prefix for registry operations
- Global arrays for chain state (`CHAIN_NAMES`, `CHAIN_PATHS`, `_RESOLVING`)
- Cross-platform `sed` usage (handles both GNU and BSD)
- Shellcheck directives where needed (`# shellcheck disable=SC1090`)

## Runtime state

Dotty stores state in `~/.dotty/`:
- `registry` — flat file of `name=path` lines
- `repos/` — auto-cloned dependency repos
- `backups/` — files replaced by symlinks
- `bin/dotty` — symlink to main script

## Repo configuration

Each managed dotfiles repo has a config file at `.dotty/config`. The `_find_config` helper resolves this path. Similarly, hooks live at `.dotty/run.sh`, resolved by `_find_hook`.

```bash
# .dotty/config (or dotty.conf at repo root)
DOTTY_NAME="my-dotfiles"
DOTTY_EXTENDS=("https://github.com/user/base-dotfiles.git")
DOTTY_ENVIRONMENTS=("laptop" "remote")
DOTTY_ENV_DETECT='[[ -n "${SSH_CONNECTION:-}" ]] && echo "remote"'
```

Files in `repo/home/` are symlinked to `$HOME`. Environment overlays live in `repo/<env>/home/`.

## Testing changes

Run the automated test suite first:

```bash
./test/bats/bin/bats test/    # run all tests (69 tests across 8 files)
```

Tests use isolated temp directories and don't touch real dotfiles. Test files live in `test/`:
- `registry.bats` — registry CRUD operations
- `symlinks.bats` — symlink creation, directory merging, orphan cleanup
- `chain.bats` — chain resolution, cycle detection, environment detection
- `dry_run.bats` — dry-run mode for symlinks and orphan cleanup
- `trace.bats` — symlink provenance tracing
- `files.bats` — file listing and status
- `uninstall.bats` — repo uninstallation and backup restore
- `migrate.bats` — `.dotty/` directory layout helpers

After tests pass, verify against the user's actual dotfiles repos. Use `./dotty status` or read `~/.dotty/registry` to discover what's registered on this machine. Common manual test workflows:

```bash
./dotty status    # see registered repos, chain order, environment
./dotty link      # re-link everything (fast, no hooks)
./dotty install   # full install cycle (symlinks + hooks)
./dotty update    # pull and re-link everything
```

For destructive or risky changes (symlink logic, chain resolution, directory merging), create a scratch repo in a temp directory to test first before running against real dotfiles.

## Keeping downstream repos in sync

After any change to dotty, check both the dotty repo itself and all downstream dotfiles repos for stale references. Never hardcode repo names or paths in this file.

### Discovery

Run `dotty status` or read `~/.dotty/registry` to find all registered repos on the user's machine. Each line in the registry is a `name=path` pair pointing to a dotfiles repo that may reference dotty concepts.

### What to check in the dotty repo

Three user-facing surfaces must stay in sync with the code:

- **`cmd_help()` in `dotty`** — the help text shown by `dotty help`. Update when adding commands, flags, or environment variables.
- **`completions/_dotty`** — zsh completions. Update when adding commands, subcommands, or flags.
- **`README.md`** — full documentation of commands, configuration format, hook contract, directory layout, options, and troubleshooting. Update when any user-visible behavior changes.

Check for changes to command behavior or flags, new or renamed environment variables, `.dotty/config` fields, hook execution semantics, and directory structure or state files.

### What to check in downstream repos

Scan each registered repo for files that reference dotty and verify they still match the current behavior:

- **CLAUDE.md files** — often contain dotty architecture docs, command references, hook contract details, and overlay semantics descriptions.
- **README.md files** — installation instructions, command examples, workflow descriptions, and configuration documentation.
- **`.dotty/run.sh` hooks** — env var usage (`DOTTY_REPO_DIR`, `DOTTY_ENV`, `DOTTY_COMMAND`, `DOTTY_LIB`) and any calls to utility library functions.
- **Shell config files** (`.zshenv.local`, `.zshrc.local`, etc.) — references to `DOTTY_ENV`, `DOTTY_GUARD_PATTERNS`, or other dotty variables.
- **`install.sh` scripts** — bootstrap logic that clones or invokes dotty.
- **Scripts that source `$DOTTY_LIB`** — any script using dotty's utility library for logging and symlinks.

### What triggers downstream updates

Not just hook contract changes. Any of these dotty changes can cause downstream drift:

- Commands (names, flags, subcommands, output format)
- Environment variables (hook vars, guard vars, detection vars)
- `.dotty/config` fields or their semantics
- Guard mechanism (pattern format, hook behavior)
- Utility library functions exposed via `$DOTTY_LIB`
- Directory layout or state file locations (`~/.dotty/` structure)
- Bootstrap/install process

### How to update

Inspect each downstream file for stale references and update them directly. Commit changes to each downstream repo separately rather than batching dotty repo changes with downstream repo changes in the same commit.
