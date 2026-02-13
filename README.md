# dotty

A bash dotfiles manager with overlay semantics. Manages a chain of dotfiles repos where later repos override earlier ones.

## Quick start

```bash
# Install dotty
curl -fsSL https://raw.githubusercontent.com/jackokerman/dotty/main/install.sh | bash

# Install your dotfiles (clones dependencies automatically)
dotty install <path-or-url>
```

If your dotfiles repo declares parent repos via `DOTTY_EXTENDS`, dotty resolves the full chain, clones anything missing, symlinks everything, and runs install hooks.

## Commands

### `dotty install <url-or-path>`

The main entry point. Resolves the dependency chain, clones missing repos, creates symlinks, and runs install hooks.

```bash
dotty install ~/my-dotfiles
dotty install https://github.com/you/work-dotfiles.git
```

### `dotty update [name]`

Pulls all repos (or a specific one) and re-runs the full symlink + hook cycle.

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

If `--repo` is omitted and multiple repos are registered, dotty prompts for which one.

### `dotty link [name]`

Re-creates symlinks without pulling repos or running hooks. Useful when you've manually edited files and want to refresh the links.

### `dotty status`

Shows registered repos, the resolved chain order, detected environment, and git status of each repo.

```
dotty status

  Chain: dotfiles → work-dotfiles
  Env:   laptop

  ✓ dotfiles (/home/you/dotfiles) [clean]
  ● work-dotfiles (/home/you/work-dotfiles) [modified]
```

### `dotty register <path> [name]`

Register an already-cloned repo without running install. The name is read from `dotty.conf` if not provided.

### `dotty unregister <name>`

Remove a repo from the registry. Does not delete the repo or its symlinks.

## Config file

Each dotfiles repo has a `dotty.conf` at its root:

```bash
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
```

| Field | Type | Required | Description |
|---|---|---|---|
| `DOTTY_NAME` | string | yes | Unique name, used as registry key |
| `DOTTY_EXTENDS` | bash array | yes (empty OK) | Git URLs of parent repos |
| `DOTTY_ENVIRONMENTS` | bash array | no | Environment names this repo supports |
| `DOTTY_ENV_DETECT` | string | no | Bash snippet that echoes detected environment |

## Directory conventions

```
repo/
├── dotty.conf              # config (required)
├── dotty-install.sh        # post-link hook (optional, must be executable)
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

Everything in `home/` gets symlinked into `$HOME`. The repo layout mirrors the filesystem layout, so `.config/` lives inside `home/` rather than as a separate directory. Dotty only has one linking root to manage.

Directories are merged, not replaced. If both your repo and `$HOME` have a `.config/` directory, dotty recurses into it and symlinks individual items. This lets multiple repos contribute to `~/.config/` without clobbering each other.

## Patterns

Dotty supports three complementary patterns for managing dotfiles across repos. It directly handles the first one; the other two live in your dotfiles.

### Override (dotty handles this)

Later repos in the chain replace symlinks from earlier repos. If both `dotfiles/home/.gitconfig` and `work-dotfiles/home/.gitconfig` exist, the work version wins. This is the overlay behavior.

### Extend (your shell config handles this)

Base configs source `.local` files provided by child repos:

```
~/.zshrc (from personal) → sources ~/.zshrc.local (from work)
~/.gitconfig (from personal) → includes ~/.gitconfig.local (from work)
```

Dotty ensures the right files are symlinked so the sourcing chain works, but the composition logic lives in the dotfiles themselves.

This is the right approach for most shell config. Rather than having dotty merge files, your base `.zshrc` defines the structure and each layer adds to it through well-defined extension points.

### Merge (install hooks handle this)

For structured data like JSON settings files, install hooks can use `jq` to merge configs:

```bash
# In dotty-install.sh
jq -s '.[0] * .[1]' "$target/settings.json" "$DOTTY_REPO_DIR/settings.json" > tmp && mv tmp "$target/settings.json"
```

## Environments vs extends

These serve different purposes:

**Extends** controls which repos are in the chain. It answers "whose config?" Personal dotfiles vs work dotfiles vs team-specific dotfiles. Each repo can fully override files from repos earlier in the chain.

**Environments** control machine-specific overlays within a single repo. They answer "which machine?" Your work dotfiles might have a `laptop/` directory with macOS helpers and a `remote/` directory with Linux-specific config.

You need both dimensions independently. A work dotfiles repo (extends personal) might still need laptop vs remote awareness (environments).

In practice, most environment-specific config is delivered through the "extend" pattern (`.zshrc.local` sources `$ENV/zsh/.zshrc`) rather than through dotty's overlay mechanism. Dotty's environment detection is mainly useful for:

1. Exporting `DOTTY_ENV` so install hooks can branch on it
2. Overlaying `$env/home/` files into `$HOME` when needed

Environment-specific directories that contain files meant to be sourced (rather than symlinked) don't need a `home/` subdirectory. They're referenced directly by the `.local` files and dotty doesn't touch them.

## Install hooks

If a repo has an executable `dotty-install.sh`, dotty runs it after creating symlinks. Two environment variables are available:

- `DOTTY_REPO_DIR` — absolute path to the repo
- `DOTTY_ENV` — detected environment (empty if none)

Hooks run with the repo as the working directory. They're the right place for:

- Installing packages (`brew bundle`, `apt install`)
- Merging JSON settings files
- Setting up services (systemd units, launchd plists)
- Anything OS-specific (guard with `[[ "$(uname -s)" == "Darwin" ]]`)

## State

Dotty stores state in `~/.dotty/`:

```
~/.dotty/
├── bin/dotty           # the script (on PATH)
├── registry            # name=path, one per line
├── repos/              # auto-cloned repos
├── backups/            # backed-up files replaced by symlinks
└── completions/        # shell completions
```

When dotty creates a symlink where a real file already exists, it moves the original to `~/.dotty/backups/` (preserving the path structure) before linking.

## Multi-repo chain example

A typical setup with personal and work dotfiles:

```bash
# personal dotfiles (dotty.conf)
DOTTY_NAME="dotfiles"
DOTTY_EXTENDS=()

# work dotfiles (dotty.conf)
DOTTY_NAME="work-dotfiles"
DOTTY_EXTENDS=("https://github.com/you/dotfiles.git")
```

Running `dotty install ~/work-dotfiles`:

1. Reads `work-dotfiles/dotty.conf`, sees it extends personal dotfiles
2. Clones personal dotfiles to `~/.dotty/repos/dotfiles` (if not already registered)
3. Symlinks `dotfiles/home/` → `$HOME` (base layer)
4. Runs `dotfiles/dotty-install.sh`
5. Symlinks `work-dotfiles/home/` → `$HOME` (overlay, wins on conflicts)
6. Runs `work-dotfiles/dotty-install.sh`

## Migration from manual install scripts

If you have existing dotfiles with an `install.sh`, you can migrate incrementally:

1. Add `dotty.conf` to your repo (this is additive, doesn't break anything)
2. Create `dotty-install.sh` with your post-link setup logic
3. Update `install.sh` to delegate to dotty when available:

```bash
#!/usr/bin/env bash
if command -v dotty >/dev/null 2>&1; then
    dotty install "$(cd "$(dirname "$0")" && pwd)"
    exit 0
fi
# ... existing install logic as fallback ...
```

This way, machines without dotty keep working. As you install dotty on each machine, they start using the new path.

## Shell completions

Zsh completions are installed to `~/.dotty/completions/`. The installer adds `fpath` automatically. Completions provide:

- Subcommand completion: `dotty <TAB>`
- Repo name completion: `dotty update <TAB>` (reads from registry)
- File completion: `dotty add <TAB>`
- `--repo` flag completion: `dotty add --repo <TAB>`

## Troubleshooting

**"No dotty.conf found"** — The target directory needs a `dotty.conf` file. This is required for every dotfiles repo that dotty manages.

**Symlink conflicts** — If a real file exists where dotty wants to create a symlink, it backs up the file to `~/.dotty/backups/` and creates the link. Check backups if something goes missing.

**Broken symlinks after moving repos** — Run `dotty link` to recreate all symlinks. If you've moved a repo, re-register it: `dotty register /new/path`.

**Chain resolution fails** — Make sure parent repos are accessible (can be cloned or are already registered). Use `dotty status` to see the current state.
