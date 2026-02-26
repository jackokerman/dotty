#!/usr/bin/env bats

load test_helper

setup() {
    setup_test_env
    load_utils
    export DOTTY_DRY_RUN=true
}

teardown() {
    teardown_test_env
}

@test "dry-run: create_symlink does not create new symlinks" {
    local source_file="$TEST_HOME/source/file.txt"
    mkdir -p "$(dirname "$source_file")"
    echo "hello" > "$source_file"

    local target="$TEST_HOME/linked-file.txt"
    run create_symlink "$source_file" "$target"
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"[dry-run]"* ]]
    [[ "$output" == *"Would link"* ]]
    # File should NOT actually be created
    [[ ! -L "$target" ]]
}

@test "dry-run: create_symlink does not update existing symlinks" {
    local old_source="$TEST_HOME/source/old.txt"
    local new_source="$TEST_HOME/source/new.txt"
    mkdir -p "$(dirname "$old_source")"
    echo "old" > "$old_source"
    echo "new" > "$new_source"

    local target="$TEST_HOME/linked.txt"
    ln -s "$old_source" "$target"

    run create_symlink "$new_source" "$target"
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"[dry-run]"* ]]
    [[ "$output" == *"Would update"* ]]
    # Symlink should still point to old source
    [[ "$(readlink "$target")" == "$old_source" ]]
}

@test "dry-run: create_symlink does not backup existing files" {
    local source_file="$TEST_HOME/source/file.txt"
    mkdir -p "$(dirname "$source_file")"
    echo "source" > "$source_file"

    local target="$TEST_HOME/existing.txt"
    echo "original" > "$target"

    run create_symlink "$source_file" "$target"
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"[dry-run]"* ]]
    [[ "$output" == *"Would backup and link"* ]]
    # Original file should still exist (not backed up)
    [[ -f "$target" ]]
    [[ ! -L "$target" ]]
    [[ "$(cat "$target")" == "original" ]]
}

@test "dry-run: cleanup_orphans does not remove dangling symlinks" {
    create_test_repo "test-repo"
    local repo_dir="$REPLY"

    add_repo_file "$repo_dir" ".bashrc" "# bashrc"
    add_repo_file "$repo_dir" ".vimrc" "set nocompatible"

    # Create symlinks (need real mode for setup)
    DOTTY_DRY_RUN=false
    create_symlinks_from_dir "$repo_dir/home" "$TEST_HOME"
    DOTTY_DRY_RUN=true

    # Remove source file to create orphan
    rm "$repo_dir/home/.vimrc"

    run cleanup_orphans "$repo_dir/home" "$TEST_HOME"
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"[dry-run]"* ]]
    [[ "$output" == *"Would remove orphan"* ]]
    # Symlink should still exist (not removed)
    [[ -L "$TEST_HOME/.vimrc" ]]
}

@test "dry-run: skipped symlinks still reported correctly" {
    local source_file="$TEST_HOME/source/file.txt"
    mkdir -p "$(dirname "$source_file")"
    echo "hello" > "$source_file"

    local target="$TEST_HOME/linked-file.txt"
    ln -s "$source_file" "$target"

    # Already correct, should skip without dry-run prefix
    run create_symlink "$source_file" "$target"
    [[ "$status" -eq 0 ]]
    [[ -L "$target" ]]
}
