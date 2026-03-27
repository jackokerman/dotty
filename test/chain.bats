#!/usr/bin/env bats

load test_helper

setup() {
    setup_test_env
    load_dotty
}

teardown() {
    teardown_test_env
}

# resolve_chain

@test "resolve_chain resolves a single repo" {
    create_test_repo "my-dotfiles"
    local repo_dir="$REPLY"

    CHAIN_NAMES=()
    CHAIN_PATHS=()
    _RESOLVING=()
    resolve_chain "$repo_dir"

    [[ ${#CHAIN_NAMES[@]} -eq 1 ]]
    [[ "${CHAIN_NAMES[0]}" == "my-dotfiles" ]]
    [[ "${CHAIN_PATHS[0]}" == "$repo_dir" ]]
}

@test "resolve_chain resolves a two-repo chain (base first)" {
    create_test_repo "base"
    local base_dir="$REPLY"

    create_test_repo "overlay" "$base_dir"
    local overlay_dir="$REPLY"

    CHAIN_NAMES=()
    CHAIN_PATHS=()
    _RESOLVING=()
    resolve_chain "$overlay_dir"

    [[ ${#CHAIN_NAMES[@]} -eq 2 ]]
    [[ "${CHAIN_NAMES[0]}" == "base" ]]
    [[ "${CHAIN_NAMES[1]}" == "overlay" ]]
}

@test "resolve_chain detects cycles" {
    # Create two repos that reference each other
    create_test_repo "repo-a"
    local dir_a="$REPLY"
    create_test_repo "repo-b"
    local dir_b="$REPLY"

    # Make them circular: a extends b, b extends a
    cat > "$dir_a/.dotty/config" <<EOF
DOTTY_NAME="repo-a"
DOTTY_EXTENDS=("$dir_b")
DOTTY_ENVIRONMENTS=()
DOTTY_ENV_DETECT=""
DOTTY_LINK_IGNORE=()
EOF

    cat > "$dir_b/.dotty/config" <<EOF
DOTTY_NAME="repo-b"
DOTTY_EXTENDS=("$dir_a")
DOTTY_ENVIRONMENTS=()
DOTTY_ENV_DETECT=""
DOTTY_LINK_IGNORE=()
EOF

    CHAIN_NAMES=()
    CHAIN_PATHS=()
    _RESOLVING=()
    run resolve_chain "$dir_a"
    [[ "$status" -ne 0 ]]
    [[ "$output" == *"cycle"* ]]
}

@test "resolve_chain handles diamond dependency (deduplication)" {
    create_test_repo "common"
    local common_dir="$REPLY"

    create_test_repo "left" "$common_dir"
    local left_dir="$REPLY"

    create_test_repo "right" "$common_dir"
    local right_dir="$REPLY"

    # Create a top repo that extends both left and right
    local top_dir="$TEST_HOME/repos/top"
    mkdir -p "$top_dir/home" "$top_dir/.dotty"
    cat > "$top_dir/.dotty/config" <<EOF
DOTTY_NAME="top"
DOTTY_EXTENDS=("$left_dir" "$right_dir")
DOTTY_ENVIRONMENTS=()
DOTTY_ENV_DETECT=""
DOTTY_LINK_IGNORE=()
EOF

    CHAIN_NAMES=()
    CHAIN_PATHS=()
    _RESOLVING=()
    resolve_chain "$top_dir"

    # common should appear exactly once
    local common_count=0
    for name in "${CHAIN_NAMES[@]}"; do
        [[ "$name" == "common" ]] && common_count=$((common_count + 1))
    done
    [[ "$common_count" -eq 1 ]]

    # Order: common, left, right, top
    [[ "${CHAIN_NAMES[0]}" == "common" ]]
    [[ "${CHAIN_NAMES[3]}" == "top" ]]
}

# resolve_chain_from_leaf

@test "resolve_chain_from_leaf picks the longest chain" {
    create_test_repo "base"
    local base_dir="$REPLY"
    register_test_repo "base" "$base_dir"

    create_test_repo "overlay" "$base_dir"
    local overlay_dir="$REPLY"
    register_test_repo "overlay" "$overlay_dir"

    CHAIN_NAMES=()
    CHAIN_PATHS=()
    resolve_chain_from_leaf

    # Should pick the overlay chain (length 2) over just base (length 1)
    [[ ${#CHAIN_NAMES[@]} -eq 2 ]]
    [[ "${CHAIN_NAMES[0]}" == "base" ]]
    [[ "${CHAIN_NAMES[1]}" == "overlay" ]]
}

# ensure_repo with target_dir

# Helper: create a bare git repo from a test repo directory
_create_bare_repo() {
    local source_dir="$1"
    local bare_dir="$TEST_HOME/bare-repos/$(basename "$source_dir").git"
    mkdir -p "$(dirname "$bare_dir")"
    git init --bare "$bare_dir" >/dev/null 2>&1
    git -C "$source_dir" init >/dev/null 2>&1
    git -C "$source_dir" add -A >/dev/null 2>&1
    git -C "$source_dir" commit -m "init" >/dev/null 2>&1
    git -C "$source_dir" remote add origin "$bare_dir" >/dev/null 2>&1
    git -C "$source_dir" push origin HEAD:main >/dev/null 2>&1
    echo "$bare_dir"
}

@test "ensure_repo clones to target_dir when provided" {
    create_test_repo "clone-target"
    local repo_dir="$REPLY"
    local bare_dir
    bare_dir="$(_create_bare_repo "$repo_dir")"

    local target="$TEST_HOME/my-target"
    local result
    result="$(ensure_repo "file://$bare_dir" "$target")"

    [[ "$result" == "$target" ]]
    [[ -d "$target" ]]
    _has_config "$target"
}

@test "ensure_repo reuses existing dotty repo at target_dir" {
    create_test_repo "reuse-me"
    local repo_dir="$REPLY"

    local target="$TEST_HOME/reuse-target"
    mkdir -p "$target/.dotty"
    cp "$repo_dir/.dotty/config" "$target/.dotty/config"

    local result
    result="$(ensure_repo "https://example.com/fake.git" "$target")"

    [[ "$result" == "$target" ]]
}

@test "ensure_repo errors when target_dir exists but is not a dotty repo" {
    local target="$TEST_HOME/not-a-dotty-repo"
    mkdir -p "$target"

    run ensure_repo "https://example.com/fake.git" "$target"
    [[ "$status" -ne 0 ]]
    [[ "$output" == *"not a dotty repo"* ]]
}

@test "ensure_repo falls back to DOTTY_REPOS_DIR without target_dir" {
    create_test_repo "fallback"
    local repo_dir="$REPLY"
    local bare_dir
    bare_dir="$(_create_bare_repo "$repo_dir")"

    local result
    result="$(ensure_repo "file://$bare_dir")"

    [[ "$result" == "$DOTTY_REPOS_DIR/fallback" ]]
    [[ -d "$DOTTY_REPOS_DIR/fallback" ]]
}

# detect_environment

@test "detect_environment returns detected env" {
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

@test "detect_environment returns empty when no detection configured" {
    create_test_repo "no-env-repo"
    local repo_dir="$REPLY"

    CHAIN_NAMES=("no-env-repo")
    CHAIN_PATHS=("$repo_dir")

    run detect_environment
    [[ -z "$output" ]]
}

@test "detect_environment uses overlay detection over base" {
    create_test_repo "base"
    local base_dir="$REPLY"
    cat > "$base_dir/.dotty/config" <<'EOF'
DOTTY_NAME="base"
DOTTY_EXTENDS=()
DOTTY_ENVIRONMENTS=()
DOTTY_ENV_DETECT='echo "base-env"'
DOTTY_LINK_IGNORE=()
EOF

    create_test_repo "overlay"
    local overlay_dir="$REPLY"
    cat > "$overlay_dir/.dotty/config" <<'EOF'
DOTTY_NAME="overlay"
DOTTY_EXTENDS=()
DOTTY_ENVIRONMENTS=("laptop" "remote")
DOTTY_ENV_DETECT='echo "overlay-env"'
DOTTY_LINK_IGNORE=()
EOF

    # Chain order: base first, overlay last
    # detect_environment walks reverse (overlay first)
    CHAIN_NAMES=("base" "overlay")
    CHAIN_PATHS=("$base_dir" "$overlay_dir")

    run detect_environment
    [[ "$output" == "overlay-env" ]]
}
