#!/usr/bin/env bash
# Shared test helpers for dotty bats tests.
#
# Each test gets an isolated environment:
#   $TEST_HOME       — fake $HOME directory
#   $TEST_DOTTY_DIR  — fake ~/.dotty state
#   $TEST_REGISTRY   — fake registry file
#   $DOTTY_SCRIPT    — absolute path to the dotty script
#   $DOTTY_LIB_PATH  — absolute path to lib/utils.sh

DOTTY_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
DOTTY_SCRIPT="$DOTTY_ROOT/dotty"
DOTTY_LIB_PATH="$DOTTY_ROOT/lib/utils.sh"

# Set up an isolated environment for each test.
setup_test_env() {
    TEST_HOME="$(mktemp -d)"
    TEST_DOTTY_DIR="$TEST_HOME/.dotty"
    TEST_REGISTRY="$TEST_DOTTY_DIR/registry"

    mkdir -p "$TEST_DOTTY_DIR" "$TEST_DOTTY_DIR/repos" "$TEST_DOTTY_DIR/backups"
    touch "$TEST_REGISTRY"

    # Override globals that utils.sh reads
    export HOME="$TEST_HOME"
    export DOTTY_DIR="$TEST_DOTTY_DIR"
    export DOTTY_REGISTRY="$TEST_REGISTRY"
    export DOTTY_REPOS_DIR="$TEST_DOTTY_DIR/repos"
    export DOTTY_BACKUPS_DIR="$TEST_DOTTY_DIR/backups"
    export DOTTY_VERBOSE="false"
    export DOTTY_LINK_IGNORE=()
}

# Clean up after each test.
teardown_test_env() {
    [[ -d "${TEST_HOME:-}" ]] && rm -rf "$TEST_HOME"
}

# Source utils.sh with a clean state (reset the double-source guard).
load_utils() {
    unset _DOTTY_LIB_LOADED
    # shellcheck source=../lib/utils.sh
    source "$DOTTY_LIB_PATH"
}

# Source the main dotty script's functions without executing main().
# This gives tests access to registry_*, resolve_chain, detect_environment, etc.
load_dotty() {
    load_utils

    # Extract function definitions from the dotty script by sourcing a modified
    # copy that removes `set -euo pipefail` (we manage that ourselves) and the
    # final `main "$@"` invocation.
    local tmp
    tmp="$(mktemp)"
    sed \
        -e 's/^set -euo pipefail$//' \
        -e 's/^main "\$@"$//' \
        -e 's|^source "$(cd "$(dirname "$0")" && pwd)/lib/utils.sh"$|# (utils already loaded)|' \
        "$DOTTY_SCRIPT" > "$tmp"
    # shellcheck disable=SC1090
    source "$tmp"
    rm -f "$tmp"
}

# Create a minimal dotty repo in a temp directory.
# Usage: create_test_repo "my-repo" [extends_url...]
# Sets REPLY to the repo path.
create_test_repo() {
    local name="$1"
    shift
    local repo_dir="$TEST_HOME/repos/$name"
    mkdir -p "$repo_dir/home" "$repo_dir/.dotty"

    local extends_array=""
    if [[ $# -gt 0 ]]; then
        extends_array="DOTTY_EXTENDS=("
        for url in "$@"; do
            extends_array+="\"$url\" "
        done
        extends_array+=")"
    else
        extends_array="DOTTY_EXTENDS=()"
    fi

    cat > "$repo_dir/.dotty/config" <<EOF
DOTTY_NAME="$name"
$extends_array
DOTTY_ENVIRONMENTS=()
DOTTY_ENV_DETECT=""
DOTTY_LINK_IGNORE=()
EOF

    REPLY="$repo_dir"
}

# Add a file to a test repo's home/ directory.
# Usage: add_repo_file "repo_path" "relative/path" ["content"]
add_repo_file() {
    local repo_dir="$1"
    local rel_path="$2"
    local content="${3:-test content}"
    local full_path="$repo_dir/home/$rel_path"

    mkdir -p "$(dirname "$full_path")"
    echo "$content" > "$full_path"
}

# Add a file to a test repo's environment overlay directory.
# Usage: add_env_file "repo_path" "env_name" "relative/path" ["content"]
add_env_file() {
    local repo_dir="$1"
    local env_name="$2"
    local rel_path="$3"
    local content="${4:-test content}"
    mkdir -p "$(dirname "$repo_dir/$env_name/home/$rel_path")"
    echo "$content" > "$repo_dir/$env_name/home/$rel_path"
}

# Register a test repo in the fake registry.
register_test_repo() {
    local name="$1"
    local path="$2"
    echo "${name}=${path}" >> "$TEST_REGISTRY"
}
