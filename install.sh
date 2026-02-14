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
COLOR_NONE="\033[0m"

info()    { echo -e "$1"; }
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
    mkdir -p "$DOTTY_DIR/lib"
    cp -rf "$tmp_dir/dotty/lib"/* "$DOTTY_DIR/lib/" 2>/dev/null || true
    rm -rf "$tmp_dir"
else
    git clone "$DOTTY_REPO" "$DOTTY_DIR" || die "Failed to clone dotty"
fi

# Set up bin directory with symlinks
mkdir -p "$DOTTY_DIR/bin"
ln -sf "$DOTTY_DIR/dotty" "$DOTTY_DIR/bin/dotty"
ln -sfn "$DOTTY_DIR/lib" "$DOTTY_DIR/bin/lib"

# Ensure directories exist
mkdir -p "$DOTTY_DIR/repos" "$DOTTY_DIR/backups"
touch "$DOTTY_DIR/registry"

# Install completions directory
mkdir -p "$DOTTY_DIR/completions"
if [[ -f "$DOTTY_DIR/completions/_dotty" ]]; then
    info "Zsh completions available"
fi

# Add dotty to PATH in .bashrc (zsh users: dotfiles handle PATH and completions)
if [[ -f "$HOME/.bashrc" ]] && ! grep -qF '.dotty/bin' "$HOME/.bashrc"; then
    echo "" >> "$HOME/.bashrc"
    echo "# dotty" >> "$HOME/.bashrc"
    echo 'export PATH="$HOME/.dotty/bin:$PATH"' >> "$HOME/.bashrc"
    info "Added dotty to PATH in .bashrc"
fi

success "dotty installed successfully!"
echo ""
echo "  Next steps:"
echo "    1. Restart your shell or run: export PATH=\"\$HOME/.dotty/bin:\$PATH\""
echo "    2. Install your dotfiles:     dotty install <path-or-url>"
echo ""
