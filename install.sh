#!/usr/bin/env bash
#
# dotty installer
#
# curl -fsSL https://raw.githubusercontent.com/jackokerman/dotty/main/install.sh | bash
#

set -euo pipefail

DOTTY_DIR="${DOTTY_DIR:-$HOME/.dotty}"
DOTTY_REPO="https://github.com/jackokerman/dotty.git"

COLOR_GREEN="\033[32m"
COLOR_RED="\033[31m"
COLOR_BLUE="\033[34m"
COLOR_NONE="\033[0m"

info()    { echo -e "${COLOR_BLUE}Info: ${COLOR_NONE}$1"; }
success() { echo -e "${COLOR_GREEN}$1${COLOR_NONE}"; }
die()     { echo -e "${COLOR_RED}Error: ${COLOR_NONE}$1" >&2; exit 1; }

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
    # Move git-tracked files into existing dir, preserving registry/repos/backups
    cp -r "$tmp_dir/dotty/.git" "$DOTTY_DIR/.git"
    cp -f "$tmp_dir/dotty/dotty" "$DOTTY_DIR/dotty" 2>/dev/null || true
    cp -f "$tmp_dir/dotty/install.sh" "$DOTTY_DIR/install.sh" 2>/dev/null || true
    cp -rf "$tmp_dir/dotty/completions" "$DOTTY_DIR/completions" 2>/dev/null || true
    rm -rf "$tmp_dir"
else
    git clone "$DOTTY_REPO" "$DOTTY_DIR" || die "Failed to clone dotty"
fi

# Set up bin directory with symlink
mkdir -p "$DOTTY_DIR/bin"
ln -sf "$DOTTY_DIR/dotty" "$DOTTY_DIR/bin/dotty"

# Ensure directories exist
mkdir -p "$DOTTY_DIR/repos" "$DOTTY_DIR/backups"
touch "$DOTTY_DIR/registry"

# Install completions directory
mkdir -p "$DOTTY_DIR/completions"
if [[ -f "$DOTTY_DIR/completions/_dotty" ]]; then
    info "Zsh completions available"
fi

# Add to PATH in shell rc files
add_to_rc() {
    local rc="$1"
    local line='export PATH="$HOME/.dotty/bin:$PATH"'
    if [[ -f "$rc" ]] && grep -qF '.dotty/bin' "$rc"; then
        return 0
    fi
    if [[ -f "$rc" ]]; then
        echo "" >> "$rc"
        echo "# dotty" >> "$rc"
        echo "$line" >> "$rc"
        info "Added dotty to PATH in $(basename "$rc")"
    fi
}

# Add fpath for zsh completions
add_fpath() {
    local rc="$1"
    local line='fpath=("$HOME/.dotty/completions" $fpath)'
    if [[ -f "$rc" ]] && grep -qF '.dotty/completions' "$rc"; then
        return 0
    fi
    if [[ -f "$rc" ]]; then
        # Add before any compinit call if possible, otherwise append
        echo "$line" >> "$rc"
        info "Added dotty completions to fpath in $(basename "$rc")"
    fi
}

add_to_rc "$HOME/.zshrc"
add_to_rc "$HOME/.bashrc"
add_fpath "$HOME/.zshrc"

echo ""
success "dotty installed successfully!"
echo ""
echo "  Next steps:"
echo "    1. Restart your shell or run: export PATH=\"\$HOME/.dotty/bin:\$PATH\""
echo "    2. Install your dotfiles:     dotty install <path-or-url>"
echo ""
