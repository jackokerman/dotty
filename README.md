# dotty

A dotfiles manager written in bash. No dependencies beyond `bash` and `git`.

Dotty manages chains of dotfiles repositories where later repos override earlier ones. You keep personal dotfiles in one repo and work-specific overrides in another, and dotty layers them together with later repos winning on conflicts. It also supports environment-specific overlays within a single repo, so the same dotfiles can behave differently on your laptop vs. a remote dev server.

## Getting started

Install dotty itself first. It's a single script that lives at `~/.dotty/bin/dotty`.

```bash
curl -fsSL https://raw.githubusercontent.com/jackokerman/dotty/main/install.sh | bash
```

> [!Note]
>
> The installer clones the dotty repo to `~/.dotty` and adds `~/.dotty/bin` to your `PATH` via `.bashrc`. If you use zsh, you'll want to add it to your `.zshrc` as well.

Once installed, point dotty at your dotfiles repo:

```bash
dotty install ~/my-dotfiles
dotty install https://github.com/you/dotfiles.git
```

If your repo declares dependencies via `DOTTY_EXTENDS`, dotty resolves the full chain, clones anything missing, symlinks everything into `$HOME`, and runs install hooks.

## Setting up your dotfiles repo

Each repo that dotty manages needs a config file at `.dotty/config`:

```bash
# .dotty/config

# Required: unique name, used as registry key
DOTTY_NAME="dotfiles"

# Required (empty is fine): git URLs of parent repos
DOTTY_EXTENDS=()

# Optional: environment names this repo supports
DOTTY_ENVIRONMENTS=("laptop" "remote")

# Optional: bash snippet that echoes the detected environment
DOTTY_ENV_DETECT='
  if [[ -n "${SSH_CONNECTION:-}" ]]; then
    echo "remote"
  else
    echo "laptop"
  fi
'

# Optional: paths (relative to home/) that dotty should not symlink.
# Useful when a hook needs full control over a file (e.g., merging JSON).
DOTTY_LINK_IGNORE=(".claude/settings.json")
```

| Field | Type | Required | Description |
|---|---|---|---|
| `DOTTY_NAME` | string | yes | Unique name, used as registry key |
| `DOTTY_EXTENDS` | bash array | yes (empty OK) | Git URLs of parent repos |
| `DOTTY_ENVIRONMENTS` | bash array | no | Environment names this repo supports |
| `DOTTY_ENV_DETECT` | string | no | Bash snippet that echoes detected environment |
| `DOTTY_LINK_IGNORE` | bash array | no | Paths (relative to `home/`) to skip during symlinking |

### Directory layout

Your repo mirrors the structure of `$HOME`. Everything in `home/` gets symlinked into `$HOME`, and environment-specific overlays live in their own directories.

```
my-dotfiles/
├── .dotty/
│   ├── config              # config (required)
│   └── run.sh              # hook script (optional, must be executable)
├── home/                   # symlinked to $HOME
│   ├── .zshrc              # → ~/.zshrc
│   ├── .gitconfig          # → ~/.gitconfig
│   └── .config/            # → ~/.config/* (merged, not replaced)
│       ├── zsh/            # → ~/.config/zsh/
│       └── git/            # → ~/.config/git/
├── laptop/                 # env-specific overlay (optional)
│   └── home/               #   overlaid onto $HOME when env=laptop
└── remote/
    └── home/               #   overlaid onto $HOME when env=remote
```


## Multi-repo chains

This is the core idea behind dotty. You keep a base layer of personal config and extend it with repo-specific overrides.

Here's a typical setup with personal and work dotfiles:

```bash
# personal dotfiles (.dotty/config)
DOTTY_NAME="dotfiles"
DOTTY_EXTENDS=()

# work dotfiles (.dotty/config)
DOTTY_NAME="work-dotfiles"
DOTTY_EXTENDS=("https://github.com/you/dotfiles.git")
```

Running `dotty install ~/work-dotfiles` kicks off the following:

1. Reads `work-dotfiles/.dotty/config`, sees it extends personal dotfiles
2. Clones personal dotfiles to `~/.dotty/repos/dotfiles` (if not already registered)
3. Symlinks `dotfiles/home/` into `$HOME` (base layer)
4. Runs `dotfiles/.dotty/run.sh`
5. Symlinks `work-dotfiles/home/` into `$HOME` (overlay, wins on conflicts)
6. Runs `work-dotfiles/.dotty/run.sh`

### Directory merging

When two repos contribute files to the same directory, dotty doesn't replace the directory wholesale. It recurses into it and symlinks individual files, so both repos coexist.

Say your personal dotfiles have `home/.config/git/config` and your work dotfiles have `home/.config/git/ignore`:

```
dotfiles/home/               work-dotfiles/home/
└── .config/git/             └── .config/git/
    └── config                   └── ignore
```

After `dotty install`, `~/.config/git/` is a real directory containing symlinks to both repos:

```
~/.config/git/
├── config → ~/dotfiles/home/.config/git/config
└── ignore → ~/work-dotfiles/home/.config/git/ignore
```

If `~/.config/git/` was already a symlink (pointing to one repo's directory), dotty "explodes" it into a real directory and re-creates individual file symlinks. This happens automatically.

### Composition patterns

Dotty supports three complementary patterns for managing config across repos. It directly handles the first one; the other two live in your dotfiles.

**Override** is what dotty does natively. Later repos in the chain replace symlinks from earlier repos. If both `dotfiles/home/.gitconfig` and `work-dotfiles/home/.gitconfig` exist, the work version wins.

**Extend** is a convention in your dotfiles. Base configs source `.local` files that overlay repos provide. Your base defines the structure and each layer adds to it through well-defined extension points.

For shell configs:

```bash
# In your base .zshrc (personal dotfiles)
[[ -f "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"
```

For git, use `[include]`:

```gitconfig
# In your base .gitconfig (personal dotfiles)
[include]
    path = ~/.gitconfig.local
```

Your work repo provides `home/.zshrc.local` and `home/.gitconfig.local` with work-specific settings. This is the right approach for most config, since it composes cleanly across any number of repos.

**Merge** is for structured data like JSON where you need to combine values from multiple repos rather than replacing the whole file. The approach is to keep the source file in `home/` for discoverability, exclude it from symlinking via `DOTTY_LINK_IGNORE`, and let a hook merge it into the target.

```bash
# .dotty/config
DOTTY_LINK_IGNORE=(".config/app/settings.json")
```

```bash
# .dotty/run.sh
target="$HOME/.config/app/settings.json"
source="$DOTTY_REPO_DIR/home/.config/app/settings.json"
mkdir -p "$(dirname "$target")"
jq -s '.[0] * .[1]' "$target" "$source" > "$target.tmp" && mv "$target.tmp" "$target"
```

The file lives in `home/` so it's easy to find and edit, but dotty skips it during symlinking because it needs to be a real file that accumulates merged content from each repo in the chain.

## Environments vs extends

These serve different purposes and you'll often want both.

**Extends** controls which repos are in the chain. It answers "whose config?" Personal dotfiles vs work dotfiles vs team-specific dotfiles. Each repo can fully override files from earlier in the chain.

**Environments** control machine-specific overlays within a single repo. They answer "which machine?" Your work dotfiles might have a `laptop/` directory with macOS helpers and a `remote/` directory with Linux-specific config.

You need both dimensions independently. A work dotfiles repo (extends personal) might still need laptop vs remote awareness (environments).

In practice, most environment-specific config is delivered through the extend pattern (`.zshrc.local` sources `$ENV/zsh/.zshrc`) rather than through dotty's overlay mechanism. Dotty's environment detection is mainly useful for exporting `DOTTY_ENV` so install hooks can branch on it, and for overlaying `$env/home/` files when needed.

## Commands

### `dotty install [url-or-path]`

The main entry point. Resolves the dependency chain, clones missing repos, creates symlinks, and runs hooks.

With an argument, it sets up a new dotfiles repo (cloning dependencies as needed). Without an argument, it re-runs the full install cycle on the existing registered repos. This is useful when you want to re-trigger one-time setup scripts (like macOS defaults) that are guarded behind `DOTTY_COMMAND == "install"`.

```bash
dotty install ~/my-dotfiles                            # first-time setup
dotty install https://github.com/you/work-dotfiles.git # from a URL
dotty install                                          # re-run install on existing repos
```

### `dotty update [name]`

Pulls all repos (or a specific one) and re-runs the full symlink and hook cycle.

```bash
dotty update              # pull and re-link everything
dotty update dotfiles     # pull just one repo, re-link the full chain
```

### `dotty add <file> [--repo <name>]`

Tracks a new dotfile by moving it into a repo and creating a symlink back.

```bash
dotty add ~/.tmux.conf --repo dotfiles

# What happens:
# 1. Moves ~/.tmux.conf → ~/dotfiles/home/.tmux.conf
# 2. Creates symlink ~/.tmux.conf → ~/dotfiles/home/.tmux.conf
# 3. Prints reminder to commit the new file
```

If `--repo` is omitted and multiple repos are registered, dotty prompts you to pick one.

### `dotty link [name]`

Re-creates symlinks without pulling repos or running hooks. Useful when you've manually edited files and want to refresh the links. Also cleans up orphan symlinks (dangling links where the source file has been removed from a repo).

### `dotty status`

Shows registered repos, the resolved chain order, detected environment, git status, and symlink health for each repo. The link counts show how many files are linked, overridden by a later repo, or unlinked (e.g., excluded via `DOTTY_LINK_IGNORE`).

```
dotty status

  Chain: dotfiles → work-dotfiles
  Env:   laptop

  ✓ dotfiles (/home/you/dotfiles) [clean] [32 linked, 1 unlinked]
  ● work-dotfiles (/home/you/work-dotfiles) [modified] [15 linked]
```

### `dotty files [repo]`

Lists all files managed by dotty, grouped by repo. Each file shows whether it's currently linked, overridden by a later repo in the chain, or not linked (e.g., excluded via `DOTTY_LINK_IGNORE`).

```bash
dotty files                # list all managed files
dotty files work-dotfiles  # list only files from one repo
```

### `dotty trace <path>`

Shows which repo a file or directory comes from. Useful for debugging your chain when you're not sure which repo is providing a particular config file.

For a symlink, it shows the source repo and relative path. For an exploded directory (a real directory containing symlinks from multiple repos), it lists each managed file and its source repo.

```bash
dotty trace ~/.config/ghostty
# ~/.config/ghostty  →  dotfiles (home/.config/ghostty)

dotty trace ~/.config/git
# ~/.config/git/config  →  dotfiles (home/.config/git/config)
# ~/.config/git/ignore  →  work-dotfiles (home/.config/git/ignore)
```

### `dotty uninstall <name>`

Cleanly removes a repo by deleting its symlinks from `$HOME`, restoring any backed-up files, and unregistering it. This is the reverse of `install` for a single repo.

```bash
dotty uninstall work-dotfiles
```

Symlinks from other repos are left untouched. If dotty backed up a file when it originally created a symlink (stored in `~/.dotty/backups/`), the backup is restored to its original location.

Supports `--dry-run` to preview what would be removed without making changes.

### `dotty register <path> [name]`

Register an already-cloned repo without running install. The name is read from the config file if not provided.

### `dotty unregister <name>`

Remove a repo from the registry. This doesn't delete the repo or its symlinks.

### Options

All options can be placed before or after the command name.

`-v`, `--verbose` — Show per-file messages instead of just summary counts. Useful for debugging which files are being linked, skipped, or cleaned up.

`-n`, `--dry-run` — Preview what would change without modifying the filesystem. Shows symlinks that would be created, updated, or removed (orphan cleanup). Hooks and git pulls are skipped entirely.

```bash
dotty --dry-run link      # see what link would do
dotty -n install           # preview a full install cycle
```

## Hooks

If a repo has an executable hook script at `.dotty/run.sh`, dotty runs it after creating symlinks during `install` and `update` (but not `link`). These environment variables are available:

- `DOTTY_REPO_DIR` — absolute path to the repo
- `DOTTY_ENV` — detected environment (empty if none)
- `DOTTY_COMMAND` — the command that invoked the hook (`install` or `update`)
- `DOTTY_VERBOSE` — `"true"` when `-v`/`--verbose` is set
- `DOTTY_LIB` — path to the hook utility library (see [Hook utilities](#hook-utilities))

Hooks run with the repo as the working directory. They're the right place for installing packages (`brew bundle`, `apt install`), merging JSON settings, setting up services, or anything OS-specific.

### Conditional execution

Since hooks run on both `install` and `update`, you can use `DOTTY_COMMAND` to control what runs when. Put fast, idempotent setup at the top level and guard one-time or slow operations behind command checks.

```bash
#!/usr/bin/env bash
# .dotty/run.sh

# Always run — fast and idempotent
setup_editor_config
setup_shell_plugins

# Guard heavier operations by command
case "$DOTTY_COMMAND" in
    install)
        brew bundle --no-lock --file="$DOTTY_REPO_DIR/Brewfile"
        ./scripts/macos-defaults.sh
        ./scripts/install-fonts.sh
        ;;
    update)
        brew bundle --no-lock --file="$DOTTY_REPO_DIR/Brewfile"
        ;;
esac
```

For scripts that should only run once ever (even across reinstalls), use a marker file:

```bash
marker="$HOME/.dotty/.macos-done"
if [[ ! -f "$marker" ]]; then
    ./scripts/macos-defaults.sh
    touch "$marker"
fi
```

### Hook utilities

Dotty ships a utility library at `lib/utils.sh` that hook scripts can source via the `DOTTY_LIB` environment variable. This gives hooks access to the same logging and symlink functions that dotty uses internally, so you don't have to maintain your own copies.

```bash
#!/usr/bin/env bash
# .dotty/run.sh
source "$DOTTY_LIB"

title "Setting up my dotfiles"
info "Installing packages..."

# Create symlinks from a custom directory into $HOME
create_symlinks_from_dir "$DOTTY_REPO_DIR/extras" "$HOME"
```

Available functions:

| Function | Description |
|---|---|
| `title "msg"` | Bold heading with blue `==>` arrow prefix |
| `info "msg"` | Plain progress message |
| `success "msg"` | Green success message |
| `warning "msg"` | Yellow warning message |
| `die "msg"` | Red error message, exits with code 1 |
| `verbose_info "msg"` | Info message that only prints when `DOTTY_VERBOSE` is `"true"` |
| `should_exclude "name"` | Returns 0 if a filename matches dotty's exclusion list |
| `create_symlink src dest` | Creates a symlink, handling backups and updates |
| `create_symlinks_from_dir src_dir dest_dir` | Recursively symlinks directory contents with merging |

The library uses a double-source guard, so sourcing it multiple times is safe.

## Shell completions

Dotty ships zsh completions in `~/.dotty/completions/`. To use them, add the directory to your `fpath` before `compinit` runs:

```zsh
# In your .zshrc, before compinit:
fpath=("$HOME/.dotty/completions" $fpath)
```

Once loaded, completions cover subcommands (`dotty <TAB>`), repo names (`dotty update <TAB>`), file paths (`dotty add <TAB>`), and the `--repo` flag.

## Guard

Dotty can install a pre-commit hook that blocks commits containing sensitive patterns. This is useful for work dotfiles where you want to prevent accidentally committing internal URLs, repo names, or other content into public repos.

### Setup

First, define the patterns you want to block by exporting `DOTTY_GUARD_PATTERNS` in your shell config. Each line is a regex pattern (case-insensitive). Blank lines and `#` comments are ignored.

```bash
export DOTTY_GUARD_PATTERNS="\
stripe-internal
corp\.stripe
go/th/
# Jira URLs
jira\.corp"
```

Then install the hook into any git repo:

```bash
dotty guard              # current directory
dotty guard ~/my-repo    # specific repo
```

The hook reads `DOTTY_GUARD_PATTERNS` at commit time and blocks the commit if any staged changes match. If the env var is unset, the hook is a no-op.

### `dotty guard [path]`

Installs the pre-commit hook into the target repo's `.git/hooks/`. If a hook already exists, dotty checks whether it's one it installed (via a marker comment). If it is, it reports "already installed". If it's a foreign hook, it prompts before overwriting.

### `dotty unguard [path]`

Removes the pre-commit hook if it was installed by dotty. If the hook is foreign, it prompts before removing.

## State

Dotty stores everything in `~/.dotty/`:

```
~/.dotty/
├── bin/dotty           # the script (on PATH)
├── lib/utils.sh        # utility library for hook scripts
├── hooks/pre-commit    # guard hook template
├── registry            # name=path, one per line
├── repos/              # auto-cloned repos
├── backups/            # backed-up files replaced by symlinks
└── completions/        # shell completions
```

When dotty creates a symlink where a real file already exists, it moves the original to `~/.dotty/backups/` (preserving the path structure) before linking.

## Testing

Tests use [bats-core](https://github.com/bats-core/bats-core), which is included as a git submodule at `test/bats/`. No installation needed beyond initializing submodules.

```bash
git submodule update --init   # first time only
./test/bats/bin/bats test/    # run all tests
./test/bats/bin/bats test/symlinks.bats  # run a single file
```

Each test gets a fully isolated environment with a temporary `$HOME`, registry, and repo directory, so nothing touches your real dotfiles. The test files are:

- `registry.bats` — registry CRUD
- `symlinks.bats` — symlink creation, directory merging, orphan cleanup
- `chain.bats` — chain resolution, cycle detection, environment detection
- `dry_run.bats` — dry-run mode
- `trace.bats` — symlink provenance tracing
- `files.bats` — file listing and status
- `uninstall.bats` — repo uninstallation and backup restore
- `migrate.bats` — `.dotty/` directory layout helpers

## Migrating from a manual install script

If you already have dotfiles with an `install.sh`, you can adopt dotty incrementally. Create a `.dotty/config` in your repo, add a `.dotty/run.sh` with your post-link setup logic, and update your `install.sh` to delegate to dotty when it's available:

```bash
#!/usr/bin/env bash
if command -v dotty >/dev/null 2>&1; then
    dotty install "$(cd "$(dirname "$0")" && pwd)"
    exit 0
fi
# ... existing install logic as fallback ...
```

Machines without dotty keep working. As you install dotty on each machine, they start using the new path.

## Auto-sync on login

If you want dotfiles to stay current on remote machines without remembering to run `dotty update`, add this to your `.zshrc` or `.bashrc`:

```bash
if command -v dotty >/dev/null 2>&1; then
    (dotty update &>/dev/null &)
fi
```

This runs `dotty update` in the background on every shell startup. It won't block your prompt and it's safe to run repeatedly since it's just `git pull` plus idempotent symlink creation.

