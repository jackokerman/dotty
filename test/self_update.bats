#!/usr/bin/env bats

load test_helper

setup() {
    setup_test_env
    load_dotty
}

teardown() {
    teardown_test_env
}

@test "self_update: skips when DOTTY_DIR is not a git repo" {
    # DOTTY_DIR exists but has no .git
    run self_update
    [[ "$status" -eq 0 ]]
    [[ -z "$output" ]]
}

@test "self_update: dry-run logs without pulling" {
    git init "$DOTTY_DIR" >/dev/null 2>&1
    (cd "$DOTTY_DIR" && git commit --allow-empty -m "init" >/dev/null 2>&1)

    export DOTTY_DRY_RUN=true
    run self_update
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"[dry-run]"* ]]
    [[ "$output" == *"Would pull dotty repo"* ]]
}

@test "cmd_self_update: reports already up to date" {
    git init "$DOTTY_DIR" >/dev/null 2>&1
    (cd "$DOTTY_DIR" && git commit --allow-empty -m "init" >/dev/null 2>&1)

    run cmd_self_update
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"Already up to date"* ]]
}

@test "cmd_self_update: dry-run logs without pulling" {
    git init "$DOTTY_DIR" >/dev/null 2>&1
    (cd "$DOTTY_DIR" && git commit --allow-empty -m "init" >/dev/null 2>&1)

    export DOTTY_DRY_RUN=true
    run cmd_self_update
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"[dry-run]"* ]]
    [[ "$output" == *"Would pull dotty repo"* ]]
}

@test "cmd_self_update: fails when DOTTY_DIR is not a git repo" {
    run cmd_self_update
    [[ "$status" -ne 0 ]]
    [[ "$output" == *"not a git repo"* ]]
}
