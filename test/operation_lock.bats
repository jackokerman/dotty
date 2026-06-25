#!/usr/bin/env bats

load test_helper

setup() {
    setup_test_env
    load_dotty
}

teardown() {
    teardown_test_env
}

@test "operation lock writes metadata and releases the lock directory" {
    _acquire_operation_lock "update"

    local lock_dir="$TEST_DOTTY_DIR/operation.lock"
    [[ -d "$lock_dir" ]]
    [[ "$(cat "$lock_dir/command")" == "update" ]]
    [[ -s "$lock_dir/pid" ]]
    [[ -s "$lock_dir/started-at" ]]

    _release_operation_lock
    [[ ! -e "$lock_dir" ]]
}

@test "operation lock removes stale lock directories" {
    local lock_dir="$TEST_DOTTY_DIR/operation.lock"
    mkdir -p "$lock_dir"
    printf '999999\n' > "$lock_dir/pid"
    printf 'update\n' > "$lock_dir/command"

    run _acquire_operation_lock "update"
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"Removing stale dotty operation lock"* ]]
    [[ "$(cat "$lock_dir/command")" == "update" ]]

    _release_operation_lock
}

@test "operation lock waits for an active lock owner" {
    local lock_dir="$TEST_DOTTY_DIR/operation.lock"
    local output_file="$TEST_HOME/wait.log"
    mkdir -p "$lock_dir"
    printf '%s\n' "$(_current_pid)" > "$lock_dir/pid"
    printf 'update\n' > "$lock_dir/command"
    printf '2026-06-25T00:00:00Z\n' > "$lock_dir/started-at"
    printf 'test-host\n' > "$lock_dir/host"

    (
        _acquire_operation_lock "link"
        _release_operation_lock
    ) > "$output_file" 2>&1 &
    local waiter_pid="$!"

    sleep 0.2
    [[ -d "$lock_dir" ]]
    rm -rf "$lock_dir"

    wait "$waiter_pid"
    [[ "$(cat "$output_file")" == *"Waiting for dotty update pid"* ]]
}
