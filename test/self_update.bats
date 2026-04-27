#!/usr/bin/env bats

load test_helper

setup() {
    setup_test_env
    load_dotty
}

teardown() {
    teardown_test_env
}

init_dotty_git_repo() {
    GIT_CONFIG_NOSYSTEM=1 git \
        -c init.defaultBranch=main \
        -c init.templateDir= \
        init "$DOTTY_DIR" >/dev/null 2>&1
    (
        cd "$DOTTY_DIR"
        GIT_CONFIG_NOSYSTEM=1 git \
            -c user.name="Dotty Tests" \
            -c user.email="dotty-tests@example.com" \
            commit --allow-empty -m "init" >/dev/null 2>&1
    )
}

@test "self_update: skips when DOTTY_DIR is not a git repo" {
    # DOTTY_DIR exists but has no .git
    run self_update
    [[ "$status" -eq 0 ]]
    [[ -z "$output" ]]
}

@test "self_update: dry-run logs without pulling" {
    init_dotty_git_repo

    export DOTTY_DRY_RUN=true
    run self_update
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"[dry-run]"* ]]
    [[ "$output" == *"Would pull dotty repo"* ]]
}

@test "cmd_self_update: reports already up to date" {
    init_dotty_git_repo

    run cmd_self_update
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"Already up to date"* ]]
}

@test "cmd_self_update: dry-run logs without pulling" {
    init_dotty_git_repo

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
