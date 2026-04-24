#!/usr/bin/env bats

load test_helper

setup() {
    setup_test_env
    load_dotty
}

teardown() {
    teardown_test_env
}

@test "cmd_doctor fails when no repos are registered" {
    run cmd_doctor
    [[ "$status" -eq 1 ]]
    [[ "$output" == *"No repos registered. Run 'dotty install' first."* ]]
}

@test "cmd_doctor succeeds on a clean layered setup" {
    create_test_repo "base"
    local base_dir="$REPLY"
    git -C "$base_dir" init -q

    create_test_repo "overlay" "$base_dir"
    local overlay_dir="$REPLY"
    git -C "$overlay_dir" init -q

    cat > "$overlay_dir/.dotty/run.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'hook\n' >/dev/null
EOF
    chmod +x "$overlay_dir/.dotty/run.sh"
    add_repo_command "$overlay_dir" "sync-dotfiles"

    register_test_repo "base" "$base_dir"
    register_test_repo "overlay" "$overlay_dir"

    run cmd_doctor
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"overlay: hook is executable"* ]]
    [[ "$output" == *"overlay: command 'sync-dotfiles' is executable"* ]]
    [[ "$output" == *"overlay: chain resolves (base → overlay)"* ]]
    [[ "$output" == *"dotty doctor found 0 failures, 0 warning(s)"* ]]
}

@test "cmd_doctor fails on a missing registered path" {
    echo "dotfiles=$TEST_HOME/missing-repo" >> "$TEST_REGISTRY"

    run cmd_doctor
    [[ "$status" -eq 1 ]]
    [[ "$output" == *"dotfiles: registered path is missing"* ]]
}

@test "cmd_doctor fails on a missing dependency in DOTTY_EXTENDS" {
    create_test_repo "dotfiles"
    local repo_dir="$REPLY"
    git -C "$repo_dir" init -q

    cat > "$repo_dir/.dotty/config" <<'EOF'
DOTTY_NAME="dotfiles"
DOTTY_EXTENDS=("https://github.com/example/missing-parent.git")
DOTTY_ENVIRONMENTS=()
DOTTY_ENV_DETECT=""
DOTTY_LINK_IGNORE=()
EOF

    register_test_repo "dotfiles" "$repo_dir"

    run cmd_doctor
    [[ "$status" -eq 1 ]]
    [[ "$output" == *"dotfiles depends on https://github.com/example/missing-parent.git, but it is not installed or registered"* ]]
}

@test "cmd_doctor fails on a non-executable hook" {
    create_test_repo "dotfiles"
    local repo_dir="$REPLY"
    git -C "$repo_dir" init -q

    cat > "$repo_dir/.dotty/run.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'hook\n' >/dev/null
EOF

    register_test_repo "dotfiles" "$repo_dir"

    run cmd_doctor
    [[ "$status" -eq 1 ]]
    [[ "$output" == *".dotty/run.sh exists but is not executable"* ]]
}

@test "cmd_doctor fails on a non-executable repo command" {
    create_test_repo "dotfiles"
    local repo_dir="$REPLY"
    git -C "$repo_dir" init -q

    mkdir -p "$repo_dir/.dotty/commands"
    cat > "$repo_dir/.dotty/commands/sync" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'sync\n'
EOF

    register_test_repo "dotfiles" "$repo_dir"

    run cmd_doctor
    [[ "$status" -eq 1 ]]
    [[ "$output" == *"command 'sync' exists but is not executable"* ]]
}

@test "cmd_doctor fails when the detected environment is undeclared" {
    create_test_repo "dotfiles"
    local repo_dir="$REPLY"
    git -C "$repo_dir" init -q

    cat > "$repo_dir/.dotty/config" <<'EOF'
DOTTY_NAME="dotfiles"
DOTTY_EXTENDS=()
DOTTY_ENVIRONMENTS=("remote")
DOTTY_ENV_DETECT='echo "laptop"'
DOTTY_LINK_IGNORE=()
EOF

    register_test_repo "dotfiles" "$repo_dir"

    run cmd_doctor
    [[ "$status" -eq 1 ]]
    [[ "$output" == *"dotfiles: detected environment 'laptop' is not listed in DOTTY_ENVIRONMENTS"* ]]
}
