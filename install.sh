#!/usr/bin/env bash
#
# dotty installer
#
# curl -fsSL https://raw.githubusercontent.com/jackokerman/dotty/main/install.sh | bash
#

set -euo pipefail

DOTTY_DIR="${DOTTY_DIR:-$HOME/.dotty}"
DOTTY_REPO="${DOTTY_REPO:-https://github.com/jackokerman/dotty.git}"

COLOR_GREEN="\033[32m"
COLOR_RED="\033[31m"
COLOR_NONE="\033[0m"

if [[ -n "${NO_COLOR:-}" ]] || [[ ! -t 1 ]]; then
    COLOR_GREEN="" COLOR_RED="" COLOR_NONE=""
fi

_shell_path_literal() {
    local path="$1"

    if [[ "$path" == "$HOME" ]]; then
        printf '%s\n' '$HOME'
    elif [[ "$path" == "$HOME/"* ]]; then
        printf '$HOME/%s\n' "${path#$HOME/}"
    else
        printf '%s\n' "$path"
    fi
}

DOTTY_PATH_LINE="export PATH=\"$(_shell_path_literal "$DOTTY_DIR/bin"):\$PATH\""
DOTTY_SHELL_INIT_LINE='eval "$(dotty shell-init)"'
CONFIGURED_RC_FILE=""
CONFIGURED_RC_LABEL=""

info()    { echo -e "  $1"; }
success() { echo -e "  ${COLOR_GREEN}✔${COLOR_NONE} $1"; }
die()     { echo -e "  ${COLOR_RED}✖${COLOR_NONE} $1" >&2; exit 1; }

configure_shell_startup() {
    local shell_name="$1"
    local rc_file
    local rc_label
    local missing_path="false"
    local missing_shell_init="false"

    case "$shell_name" in
        bash)
            rc_file="$HOME/.bashrc"
            rc_label=".bashrc"
            ;;
        zsh)
            rc_file="$HOME/.zshrc"
            rc_label=".zshrc"
            ;;
        *)
            return 1
            ;;
    esac

    touch "$rc_file"

    if ! grep -qF "$DOTTY_PATH_LINE" "$rc_file"; then
        missing_path="true"
    fi

    if ! grep -qF "$DOTTY_SHELL_INIT_LINE" "$rc_file"; then
        missing_shell_init="true"
    fi

    if [[ "$missing_path" == "false" ]] && [[ "$missing_shell_init" == "false" ]]; then
        info "Shell setup already present in $rc_label"
        CONFIGURED_RC_FILE="$rc_file"
        CONFIGURED_RC_LABEL="$rc_label"
        return 0
    fi

    if [[ -s "$rc_file" ]]; then
        printf '\n' >> "$rc_file"
    fi

    printf '%s\n' '# dotty' >> "$rc_file"

    if [[ "$missing_path" == "true" ]]; then
        printf '%s\n' "$DOTTY_PATH_LINE" >> "$rc_file"
    fi

    if [[ "$missing_shell_init" == "true" ]]; then
        printf '%s\n' "$DOTTY_SHELL_INIT_LINE" >> "$rc_file"
    fi

    if [[ "$missing_path" == "true" ]] && [[ "$missing_shell_init" == "true" ]]; then
        info "Configured dotty PATH and shell auto-reload in $rc_label"
    elif [[ "$missing_path" == "true" ]]; then
        info "Added dotty to PATH in $rc_label"
    else
        info "Enabled dotty shell auto-reload in $rc_label"
    fi

    CONFIGURED_RC_FILE="$rc_file"
    CONFIGURED_RC_LABEL="$rc_label"
}

echo ""
echo "  Installing dotty..."
echo ""

# Clone or update dotty repo
if [[ -d "$DOTTY_DIR/.git" ]]; then
    info "dotty already installed, updating..."
    (cd "$DOTTY_DIR" && git pull --ff-only 2>/dev/null) || true
elif [[ -d "$DOTTY_DIR" ]]; then
    # DOTTY_DIR exists but isn't a git repo — set up around existing state
    info "Existing ~/.dotty found, cloning dotty repo alongside..."
    tmp_dir="$(mktemp -d)"
    git clone "$DOTTY_REPO" "$tmp_dir/dotty" || die "Failed to clone dotty"
    # Restore the full tracked tree into the existing state dir while preserving
    # untracked runtime data like registry, repos, and backups.
    cp -r "$tmp_dir/dotty/.git" "$DOTTY_DIR/.git"
    (cd "$tmp_dir/dotty" && git archive --format=tar HEAD | tar -xf - -C "$DOTTY_DIR") \
        || die "Failed to restore dotty working tree"
    rm -rf "$tmp_dir"
else
    git clone "$DOTTY_REPO" "$DOTTY_DIR" || die "Failed to clone dotty"
fi

# Set up bin directory with symlinks
mkdir -p "$DOTTY_DIR/bin"
ln -sf "$DOTTY_DIR/dotty" "$DOTTY_DIR/bin/dotty"
ln -sfn "$DOTTY_DIR/lib" "$DOTTY_DIR/bin/lib"
ln -sfn "$DOTTY_DIR/hooks" "$DOTTY_DIR/bin/hooks"

# Ensure directories exist
mkdir -p "$DOTTY_DIR/repos" "$DOTTY_DIR/backups"
touch "$DOTTY_DIR/registry"

# Install completions directory
mkdir -p "$DOTTY_DIR/completions"
if [[ -f "$DOTTY_DIR/completions/_dotty" ]]; then
    info "Zsh completions available"
fi

# Symlink completion to standard XDG location so it's on fpath without
# needing to know where dotty is installed
site_functions="${XDG_DATA_HOME:-$HOME/.local/share}/zsh/site-functions"
mkdir -p "$site_functions"
if [[ -f "$DOTTY_DIR/completions/_dotty" ]]; then
    ln -sf "$DOTTY_DIR/completions/_dotty" "$site_functions/_dotty"
fi

shell_name="${SHELL##*/}"
if [[ -z "$shell_name" ]]; then
    shell_name="unknown"
fi

shell_configured="false"
if configure_shell_startup "$shell_name"; then
    shell_configured="true"
fi

success "dotty installed successfully!"
echo ""
echo "  Next steps:"
if [[ "$shell_configured" == "true" ]]; then
    echo "    1. Restart your shell or run: source \"$CONFIGURED_RC_FILE\""
    echo "    2. Install your dotfiles:     dotty install <path-or-url>"
else
    echo "    1. Add these lines to your shell startup file:"
    echo "       $DOTTY_PATH_LINE"
    echo "       $DOTTY_SHELL_INIT_LINE"
    echo "    2. Start a new shell."
    echo "    3. Install your dotfiles:     dotty install <path-or-url>"
    info "Skipped shell auto-configuration for unsupported shell: $shell_name"
fi
echo ""
