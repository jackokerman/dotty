# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository. Dotty is open source, so this file must never reference specific user directories, personal repo names, or machine-specific paths. Use `dotty status` and `~/.dotty/registry` to discover the user's setup at runtime instead.

## Project overview

Dotty is a bash dotfiles manager with overlay semantics. It manages chains of dotfiles repositories where later repos override earlier ones, with support for environment-specific overlays, directory merging, and git-based dependency resolution.

The entire tool is a single bash script (`dotty`, ~830 lines) plus an installer (`install.sh`). There is no build system, no external dependencies, and no test framework.

## Architecture

The `dotty` script is structured as a monolithic bash program with procedural sections:

1. **Logging** (color-coded output helpers: `title`, `info`, `success`, `warning`, `die`)
2. **Registry** (`registry_*` functions manage a flat `name=path` file at `~/.dotty/registry`)
3. **Config reading** (sources `dotty.conf` from each repo)
4. **Chain resolution** (recursive dependency resolution with cycle detection via `resolve_chain`)
5. **Environment detection** (evaluates `DOTTY_ENV_DETECT` from first repo that defines it)
6. **Symlink management** (`create_symlinks_for`, `_link_item`, `_explode_dir_symlink` handle recursive directory merging)
7. **Commands** (`cmd_install`, `cmd_update`, `cmd_add`, `cmd_link`, `cmd_status`, etc.)
8. **Main dispatch** (entry point routes to command functions)

**Key flow (`install`):** resolve source → resolve dependency chain → register all repos → for each repo: pull, symlink `home/`, apply environment overlay, run `dotty-run.sh` hook.

**Hook environment variables:** `DOTTY_REPO_DIR` (repo path), `DOTTY_ENV` (detected environment), `DOTTY_COMMAND` (`install`, `update`, or `link`). Hooks are skipped during `link`.

**Directory merging:** when linking directories, dotty recurses into them and symlinks individual files rather than replacing the whole directory. If a directory symlink already points elsewhere, it "explodes" it into a real directory with child symlinks to preserve both sources.

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

Each managed dotfiles repo has a `dotty.conf`:
```bash
DOTTY_NAME="my-dotfiles"
DOTTY_EXTENDS=("https://github.com/user/base-dotfiles.git")
DOTTY_ENVIRONMENTS=("laptop" "remote")
DOTTY_ENV_DETECT='[[ -d /opt/stripe ]] && echo "laptop"'
```

Files in `repo/home/` are symlinked to `$HOME`. Environment overlays live in `repo/<env>/home/`.

## Testing changes

After modifying `dotty` or `install.sh`, test against the user's actual dotfiles repos. Use `./dotty status` or read `~/.dotty/registry` to discover what's registered on this machine. Common test workflows:

```bash
./dotty status    # see registered repos, chain order, environment
./dotty link      # re-link everything (fast, no hooks)
./dotty install   # full install cycle (symlinks + hooks)
./dotty update    # pull and re-link everything
```

For destructive or risky changes (symlink logic, chain resolution, directory merging), create a scratch repo in a temp directory to test first before running against real dotfiles.

## Keeping dotfiles repos in sync

When dotty's hook contract changes (new env vars, renamed hook files, changed behavior), check the user's registered dotfiles repos and update them to match. Read `~/.dotty/registry` to find repo paths, then inspect and update those repos directly.

## Keeping the README in sync

The `README.md` documents dotty's commands, configuration format, hook contract, and directory layout. When any of these change in the code, update the README to match. Check for:

- Command behavior or flags that changed
- New or renamed environment variables
- Changes to `dotty.conf` fields
- Hook execution semantics
- Directory structure or state files
