#!/usr/bin/env bats

load test_helper

setup() {
    setup_test_env
}

teardown() {
    teardown_test_env
}

make_installer_source_repo() {
    local source_repo="$1"
    mkdir -p "$source_repo/lib" "$source_repo/hooks" "$source_repo/completions" "$source_repo/test/bats"

    cat > "$source_repo/.gitignore" <<'EOF'
registry
repos/
backups/
bin/
EOF
    cat > "$source_repo/.gitmodules" <<'EOF'
[submodule "test/bats"]
	path = test/bats
	url = https://example.com/bats.git
EOF
    echo "# sample repo" > "$source_repo/README.md"
    echo '#!/usr/bin/env bash' > "$source_repo/dotty"
    echo 'echo dotty' >> "$source_repo/dotty"
    chmod +x "$source_repo/dotty"
    echo '#!/usr/bin/env bash' > "$source_repo/install.sh"
    echo 'echo install' >> "$source_repo/install.sh"
    echo "# utils" > "$source_repo/lib/utils.sh"
    echo "# hook" > "$source_repo/hooks/pre-commit"
    echo "#compdef dotty" > "$source_repo/completions/_dotty"
    echo "vendored" > "$source_repo/test/bats/README.md"

    git -C "$source_repo" init -q
    git -C "$source_repo" add .
    git -C "$source_repo" -c user.name=Test -c user.email=test@example.com commit -q -m init
}

@test "install.sh restores a full tracked tree into an existing DOTTY_DIR" {
    local source_repo="$TEST_HOME/source-repo"
    make_installer_source_repo "$source_repo"

    mkdir -p "$DOTTY_DIR/repos" "$DOTTY_DIR/backups"
    echo "dotfiles=/tmp/example" > "$DOTTY_DIR/registry"
    echo "keep" > "$DOTTY_DIR/repos/keep.txt"
    echo "backup" > "$DOTTY_DIR/backups/original.txt"

    run env HOME="$TEST_HOME" DOTTY_DIR="$DOTTY_DIR" DOTTY_REPO="$source_repo" bash "$DOTTY_ROOT/install.sh"
    [[ "$status" -eq 0 ]]
    [[ -f "$DOTTY_DIR/README.md" ]]
    [[ -f "$DOTTY_DIR/.gitmodules" ]]
    [[ -f "$DOTTY_DIR/test/bats/README.md" ]]
    [[ -L "$DOTTY_DIR/bin/dotty" ]]
    [[ "$(cat "$DOTTY_DIR/registry")" == "dotfiles=/tmp/example" ]]
    [[ "$(cat "$DOTTY_DIR/repos/keep.txt")" == "keep" ]]
    [[ "$(cat "$DOTTY_DIR/backups/original.txt")" == "backup" ]]

    run git -C "$DOTTY_DIR" status --short
    [[ "$status" -eq 0 ]]
    [[ -z "$output" ]]
}

@test "install.sh configures bash startup when SHELL is bash" {
    local source_repo="$TEST_HOME/source-repo"
    make_installer_source_repo "$source_repo"

    run env HOME="$TEST_HOME" DOTTY_DIR="$DOTTY_DIR" DOTTY_REPO="$source_repo" SHELL=/bin/bash bash "$DOTTY_ROOT/install.sh"
    [[ "$status" -eq 0 ]]
    [[ -f "$TEST_HOME/.bashrc" ]]
    [[ "$(grep -cF 'export PATH="$HOME/.dotty/bin:$PATH"' "$TEST_HOME/.bashrc")" -eq 1 ]]
    [[ "$(grep -cF 'eval "$(dotty shell-init)"' "$TEST_HOME/.bashrc")" -eq 1 ]]
    [[ ! -e "$TEST_HOME/.zshrc" ]]
}

@test "install.sh configures zsh startup when SHELL is zsh" {
    local source_repo="$TEST_HOME/source-repo"
    make_installer_source_repo "$source_repo"

    run env HOME="$TEST_HOME" DOTTY_DIR="$DOTTY_DIR" DOTTY_REPO="$source_repo" SHELL=/bin/zsh bash "$DOTTY_ROOT/install.sh"
    [[ "$status" -eq 0 ]]
    [[ -f "$TEST_HOME/.zshrc" ]]
    [[ "$(grep -cF 'export PATH="$HOME/.dotty/bin:$PATH"' "$TEST_HOME/.zshrc")" -eq 1 ]]
    [[ "$(grep -cF 'eval "$(dotty shell-init)"' "$TEST_HOME/.zshrc")" -eq 1 ]]
    [[ ! -e "$TEST_HOME/.bashrc" ]]
}

@test "install.sh adds shell-init without duplicating an existing PATH line" {
    local source_repo="$TEST_HOME/source-repo"
    make_installer_source_repo "$source_repo"

    echo 'export PATH="$HOME/.dotty/bin:$PATH"' > "$TEST_HOME/.bashrc"

    run env HOME="$TEST_HOME" DOTTY_DIR="$DOTTY_DIR" DOTTY_REPO="$source_repo" SHELL=/bin/bash bash "$DOTTY_ROOT/install.sh"
    [[ "$status" -eq 0 ]]
    [[ "$(grep -cF 'export PATH="$HOME/.dotty/bin:$PATH"' "$TEST_HOME/.bashrc")" -eq 1 ]]
    [[ "$(grep -cF 'eval "$(dotty shell-init)"' "$TEST_HOME/.bashrc")" -eq 1 ]]
}
