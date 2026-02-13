# dotty

Most dotfiles managers assume you can install whatever you want on your machine. But if you've ever set up a work laptop with strict software policies, or tried to share a config between your personal and work machines, you know that's not always the case.

Dotty is a dotfiles manager written entirely in bash. No Ruby, no Python, no package manager required. If your machine has `bash` and `git`, you can use it. That makes it ideal for locked-down environments where you can't install tools freely, like a corporate laptop or a shared server.

The real power is in how dotty handles multiple repos. You keep your personal dotfiles in one repo and your work-specific overrides in another. Dotty chains them together so that work config overlays on top of personal config, with later repos winning on conflicts. You get a clean separation between "my stuff" and "work stuff" without duplicating anything.

It also supports environment-specific overlays within a single repo, so the same work dotfiles can behave differently on your laptop vs. a remote dev server.

## Getting started

The first thing you need to do is install dotty itself. It's a single script that lives at `~/.dotty/bin/dotty`.

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

If your repo declares dependencies via `DOTTY_EXTENDS`, dotty resolves the full chain, clones anything missing, symlinks everything into `$HOME`, and runs install hooks. One command, fully set up.

## Why dotty?

**Pure bash.** No runtime dependencies beyond `bash` and `git`. Install it anywhere, including machines where you can't run `brew install` or `pip install`.

**Multi-repo chains.** Keep personal and work dotfiles in separate repos. Dotty layers them on top of each other, with later repos overriding earlier ones. Your personal `.gitconfig` gets replaced by your work one, but your personal `.zshrc` stays intact.

**Environment overlays.** A single repo can have different configs for different machines. Laptop gets macOS helpers, remote server gets Linux-specific config. Dotty detects the environment and applies the right overlay.

**Directory merging.** When two repos both contribute to `~/.config/`, dotty doesn't clobber one with the other. It recurses into the directory and symlinks individual items, so both repos can coexist.

**Incremental adoption.** You don't have to rewrite your dotfiles to use dotty. Add a `dotty.conf`, and your existing repo works. Machines without dotty keep using your old install script.

## Setting up your dotfiles repo

Each repo that dotty manages needs a `dotty.conf` at its root:

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

### Directory layout

Your repo mirrors the structure of `$HOME`. Everything in `home/` gets symlinked into `$HOME`, and environment-specific overlays live in their own directories.

```
my-dotfiles/
├── dotty.conf              # config (required)
├── dotty-run.sh            # hook script (optional, must be executable)
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
# personal dotfiles (dotty.conf)
DOTTY_NAME="dotfiles"
DOTTY_EXTENDS=()

# work dotfiles (dotty.conf)
DOTTY_NAME="work-dotfiles"
DOTTY_EXTENDS=("https://github.com/you/dotfiles.git")
```

Running `dotty install ~/work-dotfiles` kicks off the following:

1. Reads `work-dotfiles/dotty.conf`, sees it extends personal dotfiles
2. Clones personal dotfiles to `~/.dotty/repos/dotfiles` (if not already registered)
3. Symlinks `dotfiles/home/` into `$HOME` (base layer)
4. Runs `dotfiles/dotty-run.sh`
5. Symlinks `work-dotfiles/home/` into `$HOME` (overlay, wins on conflicts)
6. Runs `work-dotfiles/dotty-run.sh`

### Composition patterns

Dotty supports three complementary patterns for managing config across repos. It directly handles the first one; the other two live in your dotfiles.

**Override** is what dotty does natively. Later repos in the chain replace symlinks from earlier repos. If both `dotfiles/home/.gitconfig` and `work-dotfiles/home/.gitconfig` exist, the work version wins.

**Extend** is a convention in your shell config. Base configs source `.local` files that child repos provide:

```
~/.zshrc (from personal) → sources ~/.zshrc.local (from work)
~/.gitconfig (from personal) → includes ~/.gitconfig.local (from work)
```

This is the right approach for most shell config. Your base `.zshrc` defines the structure and each layer adds to it through well-defined extension points.

**Merge** is for structured data like JSON. Hooks can use tools like `jq` to combine configs:

```bash
# In dotty-run.sh
jq -s '.[0] * .[1]' "$target/settings.json" "$DOTTY_REPO_DIR/settings.json" > tmp && mv tmp "$target/settings.json"
```

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

Remove a repo from the registry. This doesn't delete the repo or its symlinks.

## Hooks

If a repo has an executable `dotty-run.sh`, dotty runs it after creating symlinks during `install` and `update` (but not `link`). Three environment variables are available:

- `DOTTY_REPO_DIR` — absolute path to the repo
- `DOTTY_ENV` — detected environment (empty if none)
- `DOTTY_COMMAND` — the command that invoked the hook (`install` or `update`)

Hooks run with the repo as the working directory. They're the right place for installing packages (`brew bundle`, `apt install`), merging JSON settings, setting up services, or anything OS-specific.

### Conditional execution

Since hooks run on both `install` and `update`, you can use `DOTTY_COMMAND` to control what runs when. This is useful for one-time setup like macOS system preferences or font installation that you don't want to repeat on every update.

```bash
#!/usr/bin/env bash
# dotty-run.sh

# Always run these (idempotent, fast)
brew bundle --no-lock --file="$DOTTY_REPO_DIR/Brewfile"

# Only on first install
if [[ "$DOTTY_COMMAND" == "install" ]]; then
    ./scripts/macos-defaults.sh
    ./scripts/install-fonts.sh
fi
```

For scripts that should only run once ever (even across reinstalls), use a marker file:

```bash
marker="$HOME/.dotty/.macos-done"
if [[ ! -f "$marker" ]]; then
    ./scripts/macos-defaults.sh
    touch "$marker"
fi
```

## Shell completions

Dotty ships zsh completions in `~/.dotty/completions/`. To use them, add the directory to your `fpath` before `compinit` runs:

```zsh
# In your .zshrc, before compinit:
fpath=("$HOME/.dotty/completions" $fpath)
```

Once loaded, completions cover subcommands (`dotty <TAB>`), repo names (`dotty update <TAB>`), file paths (`dotty add <TAB>`), and the `--repo` flag.

## State

Dotty stores everything in `~/.dotty/`:

```
~/.dotty/
├── bin/dotty           # the script (on PATH)
├── registry            # name=path, one per line
├── repos/              # auto-cloned repos
├── backups/            # backed-up files replaced by symlinks
└── completions/        # shell completions
```

When dotty creates a symlink where a real file already exists, it moves the original to `~/.dotty/backups/` (preserving the path structure) before linking.

## Migrating from a manual install script

If you already have dotfiles with an `install.sh`, you can adopt dotty incrementally. Add a `dotty.conf` to your repo, create a `dotty-run.sh` with your post-link setup logic, and update your `install.sh` to delegate to dotty when it's available:

```bash
#!/usr/bin/env bash
if command -v dotty >/dev/null 2>&1; then
    dotty install "$(cd "$(dirname "$0")" && pwd)"
    exit 0
fi
# ... existing install logic as fallback ...
```

Machines without dotty keep working. As you install dotty on each machine, they start using the new path.

## Troubleshooting

**"No dotty.conf found"** — The target directory needs a `dotty.conf` file. This is required for every dotfiles repo that dotty manages.

**Symlink conflicts** — If a real file exists where dotty wants to create a symlink, it backs up the file to `~/.dotty/backups/` and creates the link. Check backups if something goes missing.

**Broken symlinks after moving repos** — Run `dotty link` to recreate all symlinks. If you've moved a repo, re-register it with `dotty register /new/path`.

**Chain resolution fails** — Make sure parent repos are accessible (can be cloned or are already registered). Use `dotty status` to see the current state.
