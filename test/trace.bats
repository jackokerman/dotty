#!/usr/bin/env bats

load test_helper

setup() {
    setup_test_env
    load_dotty
}

teardown() {
    teardown_test_env
}

@test "trace: identifies symlink provenance from a single repo" {
    create_test_repo "dotfiles"
    local repo_dir="$REPLY"
    add_repo_file "$repo_dir" ".bashrc" "# bashrc"
    register_test_repo "dotfiles" "$repo_dir"

    create_symlinks_from_dir "$repo_dir/home" "$TEST_HOME"

    run cmd_trace "$TEST_HOME/.bashrc"
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"dotfiles"* ]]
    [[ "$output" == *"home/.bashrc"* ]]
}

@test "trace: identifies correct repo in a multi-repo chain" {
    create_test_repo "base"
    local base_dir="$REPLY"
    add_repo_file "$base_dir" ".bashrc" "# base"
    register_test_repo "base" "$base_dir"

    create_test_repo "overlay"
    local overlay_dir="$REPLY"
    add_repo_file "$overlay_dir" ".bashrc" "# overlay"
    register_test_repo "overlay" "$overlay_dir"

    # Link base first, then overlay (overlay wins)
    create_symlinks_from_dir "$base_dir/home" "$TEST_HOME"
    create_symlinks_from_dir "$overlay_dir/home" "$TEST_HOME"

    run cmd_trace "$TEST_HOME/.bashrc"
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"overlay"* ]]
    [[ "$output" == *"home/.bashrc"* ]]
}

@test "trace: shows all contributing repos for an exploded directory" {
    create_test_repo "base"
    local base_dir="$REPLY"
    add_repo_file "$base_dir" ".config/app/base.conf" "base"
    register_test_repo "base" "$base_dir"

    create_test_repo "overlay"
    local overlay_dir="$REPLY"
    add_repo_file "$overlay_dir" ".config/app/overlay.conf" "overlay"
    register_test_repo "overlay" "$overlay_dir"

    create_symlinks_from_dir "$base_dir/home" "$TEST_HOME"
    create_symlinks_from_dir "$overlay_dir/home" "$TEST_HOME"

    run cmd_trace "$TEST_HOME/.config/app"
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"base"* ]]
    [[ "$output" == *"base.conf"* ]]
    [[ "$output" == *"overlay"* ]]
    [[ "$output" == *"overlay.conf"* ]]
}

@test "trace: reports non-symlink file as not managed" {
    echo "real file" > "$TEST_HOME/real.txt"

    run cmd_trace "$TEST_HOME/real.txt"
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"not a symlink"* ]]
    [[ "$output" == *"not managed by dotty"* ]]
}

@test "trace: reports unmanaged directory" {
    mkdir -p "$TEST_HOME/mydir"
    echo "stuff" > "$TEST_HOME/mydir/file.txt"

    run cmd_trace "$TEST_HOME/mydir"
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"not managed by dotty"* ]]
}

@test "trace: reports symlink not pointing into a registered repo" {
    local other="$TEST_HOME/other/file.txt"
    mkdir -p "$(dirname "$other")"
    echo "other" > "$other"
    ln -s "$other" "$TEST_HOME/foreign-link"

    run cmd_trace "$TEST_HOME/foreign-link"
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"not managed by dotty"* ]]
}

@test "trace: errors on nonexistent path" {
    run cmd_trace "$TEST_HOME/does-not-exist"
    [[ "$status" -ne 0 ]]
    [[ "$output" == *"does not exist"* ]]
}

@test "trace: handles tilde expansion" {
    create_test_repo "dotfiles"
    local repo_dir="$REPLY"
    add_repo_file "$repo_dir" ".bashrc" "# bashrc"
    register_test_repo "dotfiles" "$repo_dir"

    create_symlinks_from_dir "$repo_dir/home" "$TEST_HOME"

    run cmd_trace "~/.bashrc"
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"dotfiles"* ]]
}
