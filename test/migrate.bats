#!/usr/bin/env bats
# Tests for .dotty/ directory layout support.

load test_helper

setup() {
    setup_test_env
    load_dotty
}

teardown() {
    teardown_test_env
}

# --- _find_config / _has_config ---

@test "_find_config finds .dotty/config" {
    create_test_repo "my-repo"
    local repo_dir="$REPLY"

    run _find_config "$repo_dir"
    [[ "$status" -eq 0 ]]
    [[ "$output" == "$repo_dir/.dotty/config" ]]
}

@test "_find_config fails when no config exists" {
    local empty_dir="$TEST_HOME/repos/empty"
    mkdir -p "$empty_dir"

    run _find_config "$empty_dir"
    [[ "$status" -ne 0 ]]
}

@test "_has_config returns true for .dotty/config" {
    create_test_repo "my-repo"
    local repo_dir="$REPLY"
    _has_config "$repo_dir"
}

@test "_has_config returns false for empty repo" {
    local empty_dir="$TEST_HOME/repos/empty"
    mkdir -p "$empty_dir"
    ! _has_config "$empty_dir"
}

# --- _find_hook ---

@test "_find_hook finds .dotty/run.sh" {
    create_test_repo "my-repo"
    local repo_dir="$REPLY"
    echo '#!/bin/bash' > "$repo_dir/.dotty/run.sh"

    run _find_hook "$repo_dir"
    [[ "$status" -eq 0 ]]
    [[ "$output" == "$repo_dir/.dotty/run.sh" ]]
}

@test "_find_hook fails when no hook exists" {
    create_test_repo "no-hook"
    local repo_dir="$REPLY"

    run _find_hook "$repo_dir"
    [[ "$status" -ne 0 ]]
}

# --- read_config ---

@test "read_config reads .dotty/config" {
    create_test_repo "my-config"
    local repo_dir="$REPLY"

    read_config "$repo_dir"
    [[ "$DOTTY_NAME" == "my-config" ]]
}

@test "read_config fails without .dotty/config" {
    local empty_dir="$TEST_HOME/repos/empty"
    mkdir -p "$empty_dir"

    run read_config "$empty_dir"
    [[ "$status" -ne 0 ]]
    [[ "$output" == *"No .dotty/config found"* ]]
}

# --- detect_environment ---

@test "detect_environment reads from .dotty/config" {
    create_test_repo "env-repo"
    local repo_dir="$REPLY"

    cat > "$repo_dir/.dotty/config" <<'EOF'
DOTTY_NAME="env-repo"
DOTTY_EXTENDS=()
DOTTY_ENVIRONMENTS=("laptop" "remote")
DOTTY_ENV_DETECT='echo "laptop"'
DOTTY_LINK_IGNORE=()
EOF

    CHAIN_NAMES=("env-repo")
    CHAIN_PATHS=("$repo_dir")

    run detect_environment
    [[ "$status" -eq 0 ]]
    [[ "$output" == "laptop" ]]
}
