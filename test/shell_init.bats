#!/usr/bin/env bats

load test_helper

setup() {
    setup_test_env
    load_dotty
}

teardown() {
    teardown_test_env
}

# cmd_shell_init

@test "shell-init outputs zsh wrapper when SHELL is zsh" {
    SHELL=/bin/zsh run cmd_shell_init
    [[ "$status" -eq 0 ]]
    [[ "$output" == *'dotty()'* ]]
    [[ "$output" == *'command dotty "$@"'* ]]
    [[ "$output" == *'-o interactive'* ]]
    [[ "$output" == *'exec "$SHELL"'* ]]
}

@test "shell-init outputs bash wrapper when SHELL is bash" {
    SHELL=/bin/bash run cmd_shell_init
    [[ "$status" -eq 0 ]]
    [[ "$output" == *'dotty()'* ]]
    [[ "$output" == *'command dotty "$@"'* ]]
    [[ "$output" == *'$- == *i*'* ]]
    [[ "$output" == *'exec "$SHELL"'* ]]
}

@test "shell-init fails for unsupported shell" {
    SHELL=/bin/fish run cmd_shell_init
    [[ "$status" -ne 0 ]]
    [[ "$output" == *'Unsupported shell'* ]]
}

@test "shell-init wrapper checks .needs-reload marker" {
    SHELL=/bin/zsh run cmd_shell_init
    [[ "$output" == *'.needs-reload'* ]]
}

# _DOTTY_CHANGES_MADE flag via create_symlink

@test "create_symlink sets _DOTTY_CHANGES_MADE on new link" {
    _DOTTY_CHANGES_MADE=false
    local source_file="$TEST_HOME/source/file.txt"
    mkdir -p "$(dirname "$source_file")"
    echo "hello" > "$source_file"

    local target="$TEST_HOME/linked-file.txt"
    create_symlink "$source_file" "$target"

    [[ "$_DOTTY_CHANGES_MADE" == "true" ]]
}

@test "create_symlink does not set _DOTTY_CHANGES_MADE when already correct" {
    _DOTTY_CHANGES_MADE=false
    local source_file="$TEST_HOME/source/file.txt"
    mkdir -p "$(dirname "$source_file")"
    echo "hello" > "$source_file"

    local target="$TEST_HOME/linked-file.txt"
    ln -s "$source_file" "$target"

    create_symlink "$source_file" "$target"

    [[ "$_DOTTY_CHANGES_MADE" == "false" ]]
}

@test "create_symlink sets _DOTTY_CHANGES_MADE when updating existing link" {
    _DOTTY_CHANGES_MADE=false
    local old_source="$TEST_HOME/source/old.txt"
    local new_source="$TEST_HOME/source/new.txt"
    mkdir -p "$(dirname "$old_source")"
    echo "old" > "$old_source"
    echo "new" > "$new_source"

    local target="$TEST_HOME/linked.txt"
    ln -s "$old_source" "$target"

    create_symlink "$new_source" "$target"

    [[ "$_DOTTY_CHANGES_MADE" == "true" ]]
}

# _write_reload_marker

@test "_write_reload_marker creates file when changes made" {
    _DOTTY_CHANGES_MADE=true
    DOTTY_DRY_RUN=false

    _write_reload_marker

    [[ -f "$DOTTY_DIR/.needs-reload" ]]
}

@test "_write_reload_marker skips when no changes" {
    _DOTTY_CHANGES_MADE=false
    DOTTY_DRY_RUN=false

    _write_reload_marker

    [[ ! -f "$DOTTY_DIR/.needs-reload" ]]
}

@test "_write_reload_marker skips in dry-run mode" {
    _DOTTY_CHANGES_MADE=true
    DOTTY_DRY_RUN=true

    _write_reload_marker

    [[ ! -f "$DOTTY_DIR/.needs-reload" ]]
}
