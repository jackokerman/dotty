#!/usr/bin/env bats

load test_helper

setup() {
    setup_test_env
    load_dotty
}

teardown() {
    teardown_test_env
}

# --- _find_config / _has_config ---

@test "_find_config prefers .dotty/config over dotty.conf" {
    create_test_repo "both-layouts"
    local repo_dir="$REPLY"
    mkdir -p "$repo_dir/.dotty"
    cat > "$repo_dir/.dotty/config" <<'EOF'
DOTTY_NAME="both-layouts"
DOTTY_EXTENDS=()
DOTTY_ENVIRONMENTS=()
DOTTY_ENV_DETECT=""
DOTTY_LINK_IGNORE=()
EOF

    run _find_config "$repo_dir"
    [[ "$status" -eq 0 ]]
    [[ "$output" == "$repo_dir/.dotty/config" ]]
}

@test "_find_config falls back to dotty.conf" {
    create_test_repo "old-layout"
    local repo_dir="$REPLY"

    run _find_config "$repo_dir"
    [[ "$status" -eq 0 ]]
    [[ "$output" == "$repo_dir/dotty.conf" ]]
}

@test "_find_config fails when neither exists" {
    local empty_dir="$TEST_HOME/repos/empty"
    mkdir -p "$empty_dir"

    run _find_config "$empty_dir"
    [[ "$status" -ne 0 ]]
}

@test "_has_config returns true for .dotty/config" {
    create_test_repo_new_layout "new-layout"
    local repo_dir="$REPLY"
    _has_config "$repo_dir"
}

@test "_has_config returns true for dotty.conf" {
    create_test_repo "old-layout"
    local repo_dir="$REPLY"
    _has_config "$repo_dir"
}

@test "_has_config returns false for empty repo" {
    local empty_dir="$TEST_HOME/repos/empty"
    mkdir -p "$empty_dir"
    ! _has_config "$empty_dir"
}

# --- _find_hook ---

@test "_find_hook prefers .dotty/run.sh over dotty-run.sh" {
    create_test_repo "hook-both"
    local repo_dir="$REPLY"
    echo '#!/bin/bash' > "$repo_dir/dotty-run.sh"
    mkdir -p "$repo_dir/.dotty"
    echo '#!/bin/bash' > "$repo_dir/.dotty/run.sh"

    run _find_hook "$repo_dir"
    [[ "$status" -eq 0 ]]
    [[ "$output" == "$repo_dir/.dotty/run.sh" ]]
}

@test "_find_hook falls back to dotty-run.sh" {
    create_test_repo "hook-old"
    local repo_dir="$REPLY"
    echo '#!/bin/bash' > "$repo_dir/dotty-run.sh"

    run _find_hook "$repo_dir"
    [[ "$status" -eq 0 ]]
    [[ "$output" == "$repo_dir/dotty-run.sh" ]]
}

@test "_find_hook fails when neither exists" {
    create_test_repo "no-hook"
    local repo_dir="$REPLY"

    run _find_hook "$repo_dir"
    [[ "$status" -ne 0 ]]
}

# --- read_config with new layout ---

@test "read_config works with .dotty/config" {
    create_test_repo_new_layout "new-config"
    local repo_dir="$REPLY"

    read_config "$repo_dir"
    [[ "$DOTTY_NAME" == "new-config" ]]
}

@test "read_config works with dotty.conf (backward compat)" {
    create_test_repo "old-config"
    local repo_dir="$REPLY"

    read_config "$repo_dir"
    [[ "$DOTTY_NAME" == "old-config" ]]
}

@test "resolve_chain works with new layout repos" {
    create_test_repo_new_layout "base-new"
    local base_dir="$REPLY"

    create_test_repo_new_layout "overlay-new" "$base_dir"
    local overlay_dir="$REPLY"

    CHAIN_NAMES=()
    CHAIN_PATHS=()
    _RESOLVING=()
    resolve_chain "$overlay_dir"

    [[ ${#CHAIN_NAMES[@]} -eq 2 ]]
    [[ "${CHAIN_NAMES[0]}" == "base-new" ]]
    [[ "${CHAIN_NAMES[1]}" == "overlay-new" ]]
}

@test "resolve_chain works with mixed layout repos" {
    create_test_repo "old-base"
    local base_dir="$REPLY"

    create_test_repo_new_layout "new-overlay" "$base_dir"
    local overlay_dir="$REPLY"

    CHAIN_NAMES=()
    CHAIN_PATHS=()
    _RESOLVING=()
    resolve_chain "$overlay_dir"

    [[ ${#CHAIN_NAMES[@]} -eq 2 ]]
    [[ "${CHAIN_NAMES[0]}" == "old-base" ]]
    [[ "${CHAIN_NAMES[1]}" == "new-overlay" ]]
}

# --- cmd_migrate ---

@test "migrate moves dotty.conf to .dotty/config" {
    create_test_repo "migrate-me"
    local repo_dir="$REPLY"
    register_test_repo "migrate-me" "$repo_dir"

    cmd_migrate "migrate-me"

    [[ -f "$repo_dir/.dotty/config" ]]
    [[ ! -f "$repo_dir/dotty.conf" ]]

    # Verify config is still valid after migration
    read_config "$repo_dir"
    [[ "$DOTTY_NAME" == "migrate-me" ]]
}

@test "migrate moves dotty-run.sh to .dotty/run.sh" {
    create_test_repo "migrate-hook"
    local repo_dir="$REPLY"
    echo '#!/bin/bash' > "$repo_dir/dotty-run.sh"
    chmod +x "$repo_dir/dotty-run.sh"
    register_test_repo "migrate-hook" "$repo_dir"

    cmd_migrate "migrate-hook"

    [[ -f "$repo_dir/.dotty/run.sh" ]]
    [[ ! -f "$repo_dir/dotty-run.sh" ]]
    [[ -x "$repo_dir/.dotty/run.sh" ]]
}

@test "migrate skips already-migrated repos" {
    create_test_repo_new_layout "already-done"
    local repo_dir="$REPLY"
    register_test_repo "already-done" "$repo_dir"

    run cmd_migrate "already-done"
    [[ "$output" == *"already using .dotty/ layout"* ]]
}

@test "migrate dry-run does not move files" {
    create_test_repo "dry-migrate"
    local repo_dir="$REPLY"
    register_test_repo "dry-migrate" "$repo_dir"

    DOTTY_DRY_RUN=true
    run cmd_migrate "dry-migrate"
    DOTTY_DRY_RUN=false

    [[ "$output" == *"[dry-run]"* ]]
    [[ -f "$repo_dir/dotty.conf" ]]
    [[ ! -f "$repo_dir/.dotty/config" ]]
}

@test "migrate all repos when no target specified" {
    create_test_repo "repo-a"
    local dir_a="$REPLY"
    register_test_repo "repo-a" "$dir_a"

    create_test_repo "repo-b"
    local dir_b="$REPLY"
    register_test_repo "repo-b" "$dir_b"

    cmd_migrate

    [[ -f "$dir_a/.dotty/config" ]]
    [[ -f "$dir_b/.dotty/config" ]]
    [[ ! -f "$dir_a/dotty.conf" ]]
    [[ ! -f "$dir_b/dotty.conf" ]]
}

@test "migrate fails for unknown repo" {
    run cmd_migrate "nonexistent"
    [[ "$status" -ne 0 ]]
    [[ "$output" == *"Unknown repo"* ]]
}

# --- detect_environment with new layout ---

@test "detect_environment works with .dotty/config" {
    create_test_repo_new_layout "env-new"
    local repo_dir="$REPLY"

    cat > "$repo_dir/.dotty/config" <<'EOF'
DOTTY_NAME="env-new"
DOTTY_EXTENDS=()
DOTTY_ENVIRONMENTS=("laptop" "remote")
DOTTY_ENV_DETECT='echo "laptop"'
DOTTY_LINK_IGNORE=()
EOF

    CHAIN_NAMES=("env-new")
    CHAIN_PATHS=("$repo_dir")

    run detect_environment
    [[ "$status" -eq 0 ]]
    [[ "$output" == "laptop" ]]
}
