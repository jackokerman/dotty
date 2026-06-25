#!/usr/bin/env bats

load test_helper

setup() {
    setup_test_env
    load_dotty
}

teardown() {
    unset DOTTY_UPDATE_JOBS
    unset DOTTY_DRY_RUN
    teardown_test_env
}

make_chain() {
    create_test_repo "base"
    local base_dir="$REPLY"
    create_test_repo "overlay"
    local overlay_dir="$REPLY"

    CHAIN_NAMES=("base" "overlay")
    CHAIN_PATHS=("$base_dir" "$overlay_dir")
}

@test "DOTTY_UPDATE_JOBS defaults to one and normalizes positive integers" {
    unset DOTTY_UPDATE_JOBS
    run _normalize_update_jobs
    [[ "$status" -eq 0 ]]
    [[ "$output" == "1" ]]

    export DOTTY_UPDATE_JOBS=2
    run _normalize_update_jobs
    [[ "$status" -eq 0 ]]
    [[ "$output" == "2" ]]
}

@test "invalid DOTTY_UPDATE_JOBS warns and falls back to one" {
    export DOTTY_UPDATE_JOBS=fast
    run _normalize_update_jobs
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"Invalid DOTTY_UPDATE_JOBS 'fast'; using 1"* ]]
    [[ "${lines[$((${#lines[@]} - 1))]}" == "1" ]]

    export DOTTY_UPDATE_JOBS=0
    run _normalize_update_jobs
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"Invalid DOTTY_UPDATE_JOBS '0'; using 1"* ]]
    [[ "${lines[$((${#lines[@]} - 1))]}" == "1" ]]
}

@test "unset DOTTY_UPDATE_JOBS keeps serial pull then process behavior" {
    make_chain

    pull_if_clean() {
        printf 'pull:%s\n' "$(basename "$1")"
    }

    process_repo() {
        printf 'process:%s\n' "$(basename "$1")"
    }

    unset DOTTY_UPDATE_JOBS
    run run_chain "true" "update"
    [[ "$status" -eq 0 ]]
    [[ "$output" == $'pull:base\nprocess:base\npull:overlay\nprocess:overlay' ]]
}

@test "DOTTY_UPDATE_JOBS pulls before serial processing for full-chain update" {
    make_chain

    pull_if_clean() {
        printf 'pull:%s\n' "$(basename "$1")"
    }

    process_repo() {
        printf 'process:%s\n' "$(basename "$1")"
    }

    export DOTTY_UPDATE_JOBS=2
    run run_chain "true" "update"
    [[ "$status" -eq 0 ]]
    [[ "$output" == $'pull:base\npull:overlay\nprocess:base\nprocess:overlay' ]]
}

@test "parallel update pull logs replay in chain order" {
    make_chain

    pull_if_clean() {
        local name
        name="$(basename "$1")"
        if [[ "$name" == "base" ]]; then
            sleep 0.2
        fi
        printf 'pull:%s\n' "$name"
    }

    process_repo() {
        printf 'process:%s\n' "$(basename "$1")"
    }

    export DOTTY_UPDATE_JOBS=2
    run run_chain "true" "update"
    [[ "$status" -eq 0 ]]
    [[ "$output" == $'pull:base\npull:overlay\nprocess:base\nprocess:overlay' ]]
}

@test "parallel update pull changes propagate to parent reload marker flag" {
    make_chain

    pull_if_clean() {
        if [[ "$(basename "$1")" == "overlay" ]]; then
            _DOTTY_CHANGES_MADE=true
        fi
    }

    process_repo() {
        :
    }

    export DOTTY_UPDATE_JOBS=2
    _DOTTY_CHANGES_MADE=false
    run_chain "true" "update"
    [[ "$_DOTTY_CHANGES_MADE" == "true" ]]
}

@test "parallel update pull warnings continue without chain errors" {
    make_chain
    local log="$TEST_HOME/update.log"

    pull_if_clean() {
        warning "Failed to pull $(basename "$1")"
    }

    process_repo() {
        printf 'process:%s\n' "$(basename "$1")"
    }

    export DOTTY_UPDATE_JOBS=2
    run_chain "true" "update" > "$log" 2>&1

    [[ "$(cat "$log")" == *"Failed to pull base"* ]]
    [[ "$(cat "$log")" == *"process:base"* ]]
    [[ "$(cat "$log")" == *"process:overlay"* ]]
    [[ "$_CHAIN_HAD_ERRORS" == "false" ]]
}

@test "dry-run skips update pulls even when DOTTY_UPDATE_JOBS is greater than one" {
    make_chain
    local pull_marker="$TEST_HOME/pulled"

    pull_if_clean() {
        printf 'pulled\n' >> "$pull_marker"
    }

    process_repo() {
        printf 'process:%s\n' "$(basename "$1")"
    }

    export DOTTY_UPDATE_JOBS=2
    export DOTTY_DRY_RUN=true
    run run_chain "true" "update"
    [[ "$status" -eq 0 ]]
    [[ "$output" == $'process:base\nprocess:overlay' ]]
    [[ ! -e "$pull_marker" ]]
}

@test "DOTTY_UPDATE_JOBS does not parallelize install or no-pull update runs" {
    make_chain

    pull_if_clean() {
        printf 'pull:%s\n' "$(basename "$1")"
    }

    process_repo() {
        printf 'process:%s\n' "$(basename "$1")"
    }

    export DOTTY_UPDATE_JOBS=2
    run run_chain "true" "install"
    [[ "$status" -eq 0 ]]
    [[ "$output" == $'pull:base\nprocess:base\npull:overlay\nprocess:overlay' ]]

    run run_chain "false" "update"
    [[ "$status" -eq 0 ]]
    [[ "$output" == $'process:base\nprocess:overlay' ]]
}
