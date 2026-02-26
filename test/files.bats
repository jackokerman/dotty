#!/usr/bin/env bats

load test_helper

setup() {
    setup_test_env
    load_dotty
}

teardown() {
    teardown_test_env
}

@test "files: lists files from a single repo" {
    create_test_repo "dotfiles"
    local repo_dir="$REPLY"
    add_repo_file "$repo_dir" ".bashrc" "# bashrc"
    add_repo_file "$repo_dir" ".vimrc" "set nocompatible"
    register_test_repo "dotfiles" "$repo_dir"

    create_symlinks_from_dir "$repo_dir/home" "$TEST_HOME"

    run cmd_files
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"dotfiles"* ]]
    [[ "$output" == *".bashrc"* ]]
    [[ "$output" == *".vimrc"* ]]
}

@test "files: shows overridden files from base repo" {
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

    run cmd_files
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"overridden"* ]]
}

@test "files: filters by repo name" {
    create_test_repo "base"
    local base_dir="$REPLY"
    add_repo_file "$base_dir" ".bashrc" "# base"
    register_test_repo "base" "$base_dir"

    create_test_repo "overlay"
    local overlay_dir="$REPLY"
    add_repo_file "$overlay_dir" ".vimrc" "set nocompatible"
    register_test_repo "overlay" "$overlay_dir"

    create_symlinks_from_dir "$base_dir/home" "$TEST_HOME"
    create_symlinks_from_dir "$overlay_dir/home" "$TEST_HOME"

    run cmd_files "overlay"
    [[ "$status" -eq 0 ]]
    [[ "$output" == *".vimrc"* ]]
    [[ "$output" != *".bashrc"* ]]
}

@test "files: errors on unknown repo filter" {
    run cmd_files "nonexistent"
    [[ "$status" -ne 0 ]]
    [[ "$output" == *"Unknown repo"* ]]
}

@test "files: shows files accessible via parent directory symlink" {
    create_test_repo "dotfiles"
    local repo_dir="$REPLY"
    add_repo_file "$repo_dir" ".config/app/config.toml" "key = val"
    register_test_repo "dotfiles" "$repo_dir"

    # Symlink the whole .config/app directory (as dotty does for empty targets)
    create_symlinks_from_dir "$repo_dir/home" "$TEST_HOME"

    run cmd_files
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"config.toml"* ]]
    # Should not show "not linked" since parent dir is a symlink
    [[ "$output" != *"not linked"* ]]
}

@test "files: reports no managed files for empty repo" {
    create_test_repo "empty"
    local repo_dir="$REPLY"
    register_test_repo "empty" "$repo_dir"

    run cmd_files
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"No managed files"* ]]
}
