#!/usr/bin/env bats

load test_helper

setup() {
    setup_test_env
    load_dotty
}

teardown() {
    teardown_test_env
}

@test "cmd_add moves a file into the selected repo and links it back" {
    create_test_repo "dotfiles"
    local repo_dir="$REPLY"
    echo "# bashrc" > "$TEST_HOME/.bashrc"
    register_test_repo "dotfiles" "$repo_dir"

    run cmd_add "$TEST_HOME/.bashrc" --repo dotfiles
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"Moved:"* ]]
    [[ -L "$TEST_HOME/.bashrc" ]]
    [[ "$(readlink "$TEST_HOME/.bashrc")" == "$repo_dir/home/.bashrc" ]]
    [[ "$(cat "$repo_dir/home/.bashrc")" == "# bashrc" ]]
}

@test "cmd_add refuses to overwrite an existing file in the repo" {
    create_test_repo "dotfiles"
    local repo_dir="$REPLY"
    echo "repo version" > "$repo_dir/home/.bashrc"
    echo "home version" > "$TEST_HOME/.bashrc"
    register_test_repo "dotfiles" "$repo_dir"

    run cmd_add "$TEST_HOME/.bashrc" --repo dotfiles
    [[ "$status" -ne 0 ]]
    [[ "$output" == *"Target already exists in repo"* ]]
    [[ ! -L "$TEST_HOME/.bashrc" ]]
    [[ "$(cat "$TEST_HOME/.bashrc")" == "home version" ]]
    [[ "$(cat "$repo_dir/home/.bashrc")" == "repo version" ]]
}

@test "cmd_check is a no-op before dotty is initialized" {
    export DOTTY_DIR="$TEST_HOME/uninitialized/.dotty"
    export DOTTY_REGISTRY="$DOTTY_DIR/registry"
    export DOTTY_REPOS_DIR="$DOTTY_DIR/repos"
    export DOTTY_BACKUPS_DIR="$DOTTY_DIR/backups"
    rm -rf "$DOTTY_DIR"

    run cmd_check
    [[ "$status" -eq 0 ]]
    [[ -z "$output" ]]
    [[ -f "$DOTTY_REGISTRY" ]]
}

@test "cmd_files and cmd_status skip paths ignored by linking" {
    create_test_repo "dotfiles"
    local repo_dir="$REPLY"

    cat > "$repo_dir/.dotty/config" <<'EOF'
DOTTY_NAME="dotfiles"
DOTTY_EXTENDS=()
DOTTY_ENVIRONMENTS=()
DOTTY_ENV_DETECT=""
DOTTY_LINK_IGNORE=(".config/app/settings.json")
EOF

    git -C "$repo_dir" init -q
    mkdir -p "$repo_dir/home/.config/app"
    echo ".zcompdump" > "$repo_dir/home/.config/app/.gitignore"
    echo "transient" > "$repo_dir/home/.config/app/.zcompdump"
    echo '{"theme": "dark"}' > "$repo_dir/home/.config/app/settings.json"
    echo "enabled = true" > "$repo_dir/home/.config/app/config.toml"
    register_test_repo "dotfiles" "$repo_dir"

    read_config "$repo_dir"
    mkdir -p "$TEST_HOME/.config/app"
    create_symlinks_from_dir "$repo_dir/home" "$TEST_HOME"

    run cmd_files
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"config.toml"* ]]
    [[ "$output" != *"settings.json"* ]]
    [[ "$output" != *".zcompdump"* ]]
    local files_output="$output"
    [[ "$files_output" != *"not linked"* ]]

    run cmd_status
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"[1 linked]"* ]]
    [[ "$output" != *"unlinked"* ]]
}

@test "cmd_commands lists resolved repo-defined commands after overlay resolution" {
    create_test_repo "base"
    local base_dir="$REPLY"
    create_test_repo "overlay" "$base_dir"
    local overlay_dir="$REPLY"

    add_repo_command "$base_dir" "base-only"
    add_repo_command "$base_dir" "shared"
    add_repo_command "$overlay_dir" "overlay-only"
    add_repo_command "$overlay_dir" "shared"

    register_test_repo "base" "$base_dir"
    register_test_repo "overlay" "$overlay_dir"

    run cmd_commands
    [[ "$status" -eq 0 ]]
    [[ "$output" == $'base-only\tbase\noverlay-only\toverlay\nshared\toverlay' ]]
}

@test "cmd_run executes a repo-defined command from the defining repo root with context env vars" {
    create_test_repo "dotfiles"
    local repo_dir="$REPLY"

    add_repo_command "$repo_dir" "print-context" "$(cat <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'pwd=%s\n' "$PWD"
printf 'command=%s\n' "$DOTTY_COMMAND"
printf 'name=%s\n' "$DOTTY_RUN_NAME"
printf 'repo=%s\n' "$DOTTY_RUN_REPO"
printf 'args=%s\n' "$*"
printf 'lib=%s\n' "${DOTTY_LIB:-}"
EOF
)"
    register_test_repo "dotfiles" "$repo_dir"

    cd "$TEST_HOME"
    run cmd_run print-context foo bar
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"pwd=$repo_dir"* ]]
    [[ "$output" == *"command=run"* ]]
    [[ "$output" == *"name=print-context"* ]]
    [[ "$output" == *"repo=$repo_dir"* ]]
    [[ "$output" == *"args=foo bar"* ]]
    [[ "$output" =~ lib=.*/lib/utils\.sh ]]
}

@test "cmd_run dry-run does not execute the resolved command" {
    create_test_repo "dotfiles"
    local repo_dir="$REPLY"
    local marker="$TEST_HOME/ran"

    add_repo_command "$repo_dir" "touch-marker" "$(cat <<EOF
#!/usr/bin/env bash
set -euo pipefail
touch "$marker"
EOF
)"
    register_test_repo "dotfiles" "$repo_dir"

    export DOTTY_DRY_RUN=true
    run cmd_run touch-marker
    unset DOTTY_DRY_RUN

    [[ "$status" -eq 0 ]]
    [[ "$output" == *"[dry-run] Would run command 'touch-marker' from dotfiles"* ]]
    [[ ! -e "$marker" ]]
}

@test "cmd_run fails when a later overlay shadows a command with a non-executable file" {
    create_test_repo "base"
    local base_dir="$REPLY"
    create_test_repo "overlay" "$base_dir"
    local overlay_dir="$REPLY"

    add_repo_command "$base_dir" "shared"
    mkdir -p "$overlay_dir/.dotty/commands"
    cat > "$overlay_dir/.dotty/commands/shared" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'overlay\n'
EOF

    register_test_repo "base" "$base_dir"
    register_test_repo "overlay" "$overlay_dir"

    run cmd_run shared
    [[ "$status" -ne 0 ]]
    [[ "$output" == *"exists but is not executable"* ]]
    [[ "$output" == *"$overlay_dir/.dotty/commands/shared"* ]]
}

@test "main passes dotty global flags through to repo commands after --" {
    create_test_repo "dotfiles"
    local repo_dir="$REPLY"

    add_repo_command "$repo_dir" "print-args" "$(cat <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'args=%s\n' "$*"
EOF
)"
    register_test_repo "dotfiles" "$repo_dir"

    run "$DOTTY_SCRIPT" run print-args -- --verbose -n
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"args=--verbose -n"* ]]
}
