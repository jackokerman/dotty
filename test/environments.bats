#!/usr/bin/env bats

load test_helper

setup() {
    setup_test_env
    load_dotty
}

teardown() {
    teardown_test_env
}

# Helper: create a repo with env detection and declared environments.
create_env_repo() {
    local name="$1"
    local env_name="$2"
    create_test_repo "$name"
    local repo_dir="$REPLY"

    cat > "$repo_dir/.dotty/config" <<EOF
DOTTY_NAME="$name"
DOTTY_EXTENDS=()
DOTTY_ENVIRONMENTS=("$env_name")
DOTTY_ENV_DETECT='echo "$env_name"'
DOTTY_LINK_IGNORE=()
EOF

    REPLY="$repo_dir"
}

@test "overlay links env/home/ files to HOME when env is detected and declared" {
    create_env_repo "test-repo" "laptop"
    local repo_dir="$REPLY"

    add_repo_file "$repo_dir" ".bashrc" "# base"
    add_env_file "$repo_dir" "laptop" ".env_only" "# env file"

    registry_set "test-repo" "$repo_dir"
    CHAIN_NAMES=("test-repo")
    CHAIN_PATHS=("$repo_dir")

    process_repo "$repo_dir" "laptop" "link"

    [[ -L "$TEST_HOME/.bashrc" ]]
    [[ -L "$TEST_HOME/.env_only" ]]
    [[ "$(readlink "$TEST_HOME/.env_only")" == "$repo_dir/laptop/home/.env_only" ]]
}

@test "overlay overrides base home/ file" {
    create_env_repo "test-repo" "laptop"
    local repo_dir="$REPLY"

    add_repo_file "$repo_dir" ".bashrc" "# base version"
    add_env_file "$repo_dir" "laptop" ".bashrc" "# laptop version"

    registry_set "test-repo" "$repo_dir"
    CHAIN_NAMES=("test-repo")
    CHAIN_PATHS=("$repo_dir")

    process_repo "$repo_dir" "laptop" "link"

    [[ -L "$TEST_HOME/.bashrc" ]]
    [[ "$(readlink "$TEST_HOME/.bashrc")" == "$repo_dir/laptop/home/.bashrc" ]]
}

@test "overlay and base both contribute to a merged directory" {
    create_env_repo "test-repo" "laptop"
    local repo_dir="$REPLY"

    add_repo_file "$repo_dir" ".config/base.conf" "base"
    add_env_file "$repo_dir" "laptop" ".config/env.conf" "env"

    registry_set "test-repo" "$repo_dir"
    CHAIN_NAMES=("test-repo")
    CHAIN_PATHS=("$repo_dir")

    process_repo "$repo_dir" "laptop" "link"

    [[ -L "$TEST_HOME/.config/base.conf" ]]
    [[ -L "$TEST_HOME/.config/env.conf" ]]
    [[ "$(readlink "$TEST_HOME/.config/base.conf")" == "$repo_dir/home/.config/base.conf" ]]
    [[ "$(readlink "$TEST_HOME/.config/env.conf")" == "$repo_dir/laptop/home/.config/env.conf" ]]
}

@test "overlay skipped when DOTTY_ENVIRONMENTS is empty" {
    create_test_repo "test-repo"
    local repo_dir="$REPLY"

    # Config has empty DOTTY_ENVIRONMENTS (the default from create_test_repo)
    add_repo_file "$repo_dir" ".bashrc" "# base"
    add_env_file "$repo_dir" "laptop" ".env_only" "# should not be linked"

    registry_set "test-repo" "$repo_dir"
    CHAIN_NAMES=("test-repo")
    CHAIN_PATHS=("$repo_dir")

    process_repo "$repo_dir" "laptop" "link"

    [[ -L "$TEST_HOME/.bashrc" ]]
    [[ ! -L "$TEST_HOME/.env_only" ]]
}

@test "overlay skipped with warning when detected env not in DOTTY_ENVIRONMENTS" {
    create_test_repo "test-repo"
    local repo_dir="$REPLY"

    cat > "$repo_dir/.dotty/config" <<'EOF'
DOTTY_NAME="test-repo"
DOTTY_EXTENDS=()
DOTTY_ENVIRONMENTS=("remote")
DOTTY_ENV_DETECT='echo "laptop"'
DOTTY_LINK_IGNORE=()
EOF

    add_repo_file "$repo_dir" ".bashrc" "# base"
    add_env_file "$repo_dir" "laptop" ".env_only" "# should not be linked"

    registry_set "test-repo" "$repo_dir"
    CHAIN_NAMES=("test-repo")
    CHAIN_PATHS=("$repo_dir")

    run process_repo "$repo_dir" "laptop" "link"

    [[ "$output" == *"not in DOTTY_ENVIRONMENTS"* ]]
    [[ ! -L "$TEST_HOME/.env_only" ]]
}

@test "orphan cleanup works for env overlay files" {
    create_env_repo "test-repo" "laptop"
    local repo_dir="$REPLY"

    add_env_file "$repo_dir" "laptop" ".env_file" "# env"

    registry_set "test-repo" "$repo_dir"
    CHAIN_NAMES=("test-repo")
    CHAIN_PATHS=("$repo_dir")

    process_repo "$repo_dir" "laptop" "link"
    [[ -L "$TEST_HOME/.env_file" ]]

    # Remove the source file to simulate deletion
    rm "$repo_dir/laptop/home/.env_file"

    process_repo "$repo_dir" "laptop" "link"

    # Orphan symlink should have been cleaned up
    [[ ! -L "$TEST_HOME/.env_file" ]]
}

@test "uninstall removes env overlay symlinks" {
    create_env_repo "test-repo" "laptop"
    local repo_dir="$REPLY"

    add_repo_file "$repo_dir" ".bashrc" "# base"
    add_env_file "$repo_dir" "laptop" ".env_only" "# env"

    registry_set "test-repo" "$repo_dir"
    CHAIN_NAMES=("test-repo")
    CHAIN_PATHS=("$repo_dir")

    create_symlinks_from_dir "$repo_dir/home" "$TEST_HOME"
    create_symlinks_from_dir "$repo_dir/laptop/home" "$TEST_HOME"

    [[ -L "$TEST_HOME/.bashrc" ]]
    [[ -L "$TEST_HOME/.env_only" ]]

    cmd_uninstall "test-repo"

    [[ ! -L "$TEST_HOME/.bashrc" ]]
    [[ ! -L "$TEST_HOME/.env_only" ]]
}

@test "DOTTY_LINK_IGNORE patterns apply to env overlays" {
    create_test_repo "test-repo"
    local repo_dir="$REPLY"

    cat > "$repo_dir/.dotty/config" <<'EOF'
DOTTY_NAME="test-repo"
DOTTY_EXTENDS=()
DOTTY_ENVIRONMENTS=("laptop")
DOTTY_ENV_DETECT='echo "laptop"'
DOTTY_LINK_IGNORE=(".ignored")
EOF

    add_env_file "$repo_dir" "laptop" ".linked" "# should link"
    add_env_file "$repo_dir" "laptop" ".ignored" "# should be ignored"

    registry_set "test-repo" "$repo_dir"
    CHAIN_NAMES=("test-repo")
    CHAIN_PATHS=("$repo_dir")

    process_repo "$repo_dir" "laptop" "link"

    [[ -L "$TEST_HOME/.linked" ]]
    [[ ! -L "$TEST_HOME/.ignored" ]]
}
