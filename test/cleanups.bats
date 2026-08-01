#!/usr/bin/env bats

load test_helper

setup() {
    setup_test_env
    load_dotty
}

teardown() {
    teardown_test_env
}

add_cleanup_file() {
    local repo_dir="$1"
    local id="$2"
    local body="$3"
    local cleanup_path="$repo_dir/.dotty/cleanups/$id"

    mkdir -p "$(dirname "$cleanup_path")"
    printf '%s\n' "$body" > "$cleanup_path"
    chmod +x "$cleanup_path"
}

add_cleanup_dir() {
    local repo_dir="$1"
    local id="$2"
    local body="$3"
    local config="${4:-}"
    local cleanup_dir="$repo_dir/.dotty/cleanups/$id"

    mkdir -p "$cleanup_dir"
    printf '%s\n' "$body" > "$cleanup_dir/run.sh"
    chmod +x "$cleanup_dir/run.sh"
    if [[ -n "$config" ]]; then
        printf '%s\n' "$config" > "$cleanup_dir/config"
    fi
}

@test "cleanup scripts run during install and update but not link" {
    create_test_repo "dotfiles"
    local repo_dir="$REPLY"
    local marker="$TEST_HOME/cleanup-runs"

    add_cleanup_file "$repo_dir" "record-command" "$(cat <<EOF
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "\$DOTTY_COMMAND" >> "$marker"
EOF
)"

    run process_repo "$repo_dir" "" "install"
    [[ "$status" -eq 0 ]]
    [[ "$(cat "$marker")" == "install" ]]

    rm -rf "$TEST_DOTTY_DIR/cleanups/dotfiles/record-command"
    run process_repo "$repo_dir" "" "update"
    [[ "$status" -eq 0 ]]
    [[ "$(cat "$marker")" == $'install\nupdate' ]]

    rm -rf "$TEST_DOTTY_DIR/cleanups/dotfiles/record-command"
    run process_repo "$repo_dir" "" "link"
    [[ "$status" -eq 0 ]]
    [[ "$(cat "$marker")" == $'install\nupdate' ]]
}

@test "successful cleanup is marked done and skipped on the next update" {
    create_test_repo "dotfiles"
    local repo_dir="$REPLY"
    local marker="$TEST_HOME/cleanup-count"

    add_cleanup_file "$repo_dir" "once" "$(cat <<EOF
#!/usr/bin/env bash
set -euo pipefail
printf 'run\n' >> "$marker"
printf 'id=%s\n' "\$DOTTY_CLEANUP_ID" > "\$DOTTY_CLEANUP_STATE_DIR/context"
EOF
)"

    process_repo "$repo_dir" "" "update"
    process_repo "$repo_dir" "" "update"

    [[ "$(cat "$marker")" == "run" ]]
    [[ -f "$TEST_DOTTY_DIR/cleanups/dotfiles/once/done" ]]
    [[ -f "$TEST_DOTTY_DIR/cleanups/dotfiles/once/completed-at" ]]
    [[ "$(cat "$TEST_DOTTY_DIR/cleanups/dotfiles/once/context")" == "id=once" ]]
}

@test "failed cleanup is not marked done and appears in the warning summary" {
    create_test_repo "dotfiles"
    local repo_dir="$REPLY"
    register_test_repo "dotfiles" "$repo_dir"

    add_cleanup_file "$repo_dir" "fails" "$(cat <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exit 7
EOF
)"

    CHAIN_NAMES=("dotfiles")
    CHAIN_PATHS=("$repo_dir")

    run run_chain "false" "update"
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"cleanup 'fails' failed in dotfiles (exit 7)"* ]]
    [[ "$output" == *"Cleanup failures: dotfiles/fails"* ]]
    [[ -f "$TEST_DOTTY_DIR/cleanups/dotfiles/fails/failed" ]]
    [[ ! -f "$TEST_DOTTY_DIR/cleanups/dotfiles/fails/done" ]]
}

@test "dry-run reports pending cleanups without executing or writing state" {
    create_test_repo "dotfiles"
    local repo_dir="$REPLY"
    local marker="$TEST_HOME/ran"

    add_cleanup_file "$repo_dir" "pending" "$(cat <<EOF
#!/usr/bin/env bash
set -euo pipefail
touch "$marker"
EOF
)"

    export DOTTY_DRY_RUN=true
    run process_repo "$repo_dir" "" "update"
    unset DOTTY_DRY_RUN

    [[ "$status" -eq 0 ]]
    [[ "$output" == *"[dry-run] Would run cleanup 'pending' in dotfiles"* ]]
    [[ ! -e "$marker" ]]
    [[ ! -e "$TEST_DOTTY_DIR/cleanups/dotfiles/pending" ]]
}

@test "environment and machine filters include only applicable cleanups" {
    create_test_repo "dotfiles"
    local repo_dir="$REPLY"
    local marker="$TEST_HOME/filter-runs"
    printf 'laptop-1\n' > "$TEST_DOTTY_DIR/machine-id"

    add_cleanup_dir "$repo_dir" "matches" "$(cat <<EOF
#!/usr/bin/env bash
set -euo pipefail
printf 'matches\n' >> "$marker"
EOF
)" "$(cat <<'EOF'
DOTTY_CLEANUP_ENVIRONMENTS=("laptop")
DOTTY_CLEANUP_MACHINES=("laptop-1")
EOF
)"
    add_cleanup_dir "$repo_dir" "wrong-env" "$(cat <<EOF
#!/usr/bin/env bash
set -euo pipefail
printf 'wrong-env\n' >> "$marker"
EOF
)" 'DOTTY_CLEANUP_ENVIRONMENTS=("remote")'
    add_cleanup_dir "$repo_dir" "wrong-machine" "$(cat <<EOF
#!/usr/bin/env bash
set -euo pipefail
printf 'wrong-machine\n' >> "$marker"
EOF
)" 'DOTTY_CLEANUP_MACHINES=("remote-1")'

    run process_repo "$repo_dir" "laptop" "update"
    [[ "$status" -eq 0 ]]
    [[ "$(cat "$marker")" == "matches" ]]
    [[ -f "$TEST_DOTTY_DIR/cleanups/dotfiles/matches/done" ]]
    [[ ! -e "$TEST_DOTTY_DIR/cleanups/dotfiles/wrong-env" ]]
    [[ ! -e "$TEST_DOTTY_DIR/cleanups/dotfiles/wrong-machine" ]]
}

@test "cleanup retirement dates require valid calendar dates" {
    local config="$TEST_HOME/cleanup-config"

    printf '%s\n' 'DOTTY_CLEANUP_RETIRE_AFTER="2024-02-29"' > "$config"
    run _load_cleanup_config_file "$config"
    [[ "$status" -eq 0 ]]

    printf '%s\n' 'DOTTY_CLEANUP_RETIRE_AFTER="2025-02-29"' > "$config"
    ! _load_cleanup_config_file "$config"
    [[ "$_CLEANUP_CONFIG_LOAD_ERROR" == *"must be a valid YYYY-MM-DD date"* ]]
}

@test "dotty cleanups lists pending and completed tasks from the resolved chain" {
    create_test_repo "base"
    local base_dir="$REPLY"
    create_test_repo "overlay" "$base_dir"
    local overlay_dir="$REPLY"

    add_cleanup_file "$base_dir" "shared-name" '#!/usr/bin/env bash'
    add_cleanup_dir "$overlay_dir" "shared-name" '#!/usr/bin/env bash' 'DOTTY_CLEANUP_DESCRIPTION="Overlay cleanup"'
    register_test_repo "base" "$base_dir"
    register_test_repo "overlay" "$overlay_dir"
    mkdir -p "$TEST_DOTTY_DIR/cleanups/base/shared-name"
    : > "$TEST_DOTTY_DIR/cleanups/base/shared-name/done"

    run cmd_cleanups
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"base"* ]]
    [[ "$output" == *"done  shared-name"* ]]
    [[ "$output" == *"overlay"* ]]
    [[ "$output" == *"pending  shared-name  Overlay cleanup"* ]]
}

@test "dotty cleanups --all includes non-applicable tasks" {
    create_test_repo "dotfiles"
    local repo_dir="$REPLY"
    add_cleanup_dir "$repo_dir" "remote-only" '#!/usr/bin/env bash' 'DOTTY_CLEANUP_ENVIRONMENTS=("remote")'
    register_test_repo "dotfiles" "$repo_dir"

    run cmd_cleanups
    [[ "$status" -eq 0 ]]
    [[ "$output" != *"remote-only"* ]]

    run cmd_cleanups --all
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"not applicable  remote-only"* ]]
}

@test "dotty cleanups marks only overdue completed applicable tasks for retirement" {
    create_test_repo "dotfiles"
    local repo_dir="$REPLY"
    local today
    today="$(date -u '+%Y-%m-%d')"

    add_cleanup_dir "$repo_dir" "retire-due" '#!/usr/bin/env bash' 'DOTTY_CLEANUP_DESCRIPTION="Old state"'$'\n''DOTTY_CLEANUP_RETIRE_AFTER="2000-01-01"'
    add_cleanup_dir "$repo_dir" "done-today" '#!/usr/bin/env bash' "DOTTY_CLEANUP_RETIRE_AFTER=\"$today\""
    add_cleanup_dir "$repo_dir" "done-future" '#!/usr/bin/env bash' 'DOTTY_CLEANUP_RETIRE_AFTER="9999-12-31"'
    add_cleanup_dir "$repo_dir" "done-undated" '#!/usr/bin/env bash'
    add_cleanup_dir "$repo_dir" "failed-due" '#!/usr/bin/env bash' 'DOTTY_CLEANUP_RETIRE_AFTER="2000-01-01"'
    add_cleanup_dir "$repo_dir" "remote-due" '#!/usr/bin/env bash' 'DOTTY_CLEANUP_ENVIRONMENTS=("remote")'$'\n''DOTTY_CLEANUP_RETIRE_AFTER="2000-01-01"'
    register_test_repo "dotfiles" "$repo_dir"

    local cleanup_id
    for cleanup_id in retire-due done-today done-future done-undated remote-due; do
        mkdir -p "$TEST_DOTTY_DIR/cleanups/dotfiles/$cleanup_id"
        : > "$TEST_DOTTY_DIR/cleanups/dotfiles/$cleanup_id/done"
    done
    mkdir -p "$TEST_DOTTY_DIR/cleanups/dotfiles/failed-due"
    : > "$TEST_DOTTY_DIR/cleanups/dotfiles/failed-due/failed"

    run cmd_cleanups --all
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"retire  retire-due  Old state (after 2000-01-01)"* ]]
    [[ "$output" == *"done  done-today"* ]]
    [[ "$output" == *"done  done-future"* ]]
    [[ "$output" == *"done  done-undated"* ]]
    [[ "$output" == *"failed  failed-due"* ]]
    [[ "$output" == *"not applicable  remote-due"* ]]
    [[ "$output" == *"Retirement dates are advisory and completion is local."* ]]

    run cmd_cleanups --pending
    [[ "$status" -eq 0 ]]
    [[ "$output" != *"retire-due"* ]]
}

@test "overdue pending cleanup stays pending and executes during update" {
    create_test_repo "dotfiles"
    local repo_dir="$REPLY"
    local marker="$TEST_HOME/pending-ran"
    add_cleanup_dir "$repo_dir" "pending-due" "$(cat <<EOF
#!/usr/bin/env bash
set -euo pipefail
touch "$marker"
printf '%s\n' "\${DOTTY_CLEANUP_RETIRE_AFTER-unset}" > "$marker-metadata"
EOF
)" 'export DOTTY_CLEANUP_RETIRE_AFTER="2000-01-01"'
    register_test_repo "dotfiles" "$repo_dir"

    run cmd_cleanups
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"pending  pending-due"* ]]
    [[ "$output" != *"Retirement dates are advisory"* ]]

    run process_repo "$repo_dir" "" "update"
    [[ "$status" -eq 0 ]]
    [[ -e "$marker" ]]
    [[ "$(cat "$marker-metadata")" == "unset" ]]
    [[ -e "$TEST_DOTTY_DIR/cleanups/dotfiles/pending-due/done" ]]
}

@test "retirement guidance appears once across layered repos" {
    create_test_repo "base"
    local base_dir="$REPLY"
    create_test_repo "overlay" "$base_dir"
    local overlay_dir="$REPLY"

    add_cleanup_dir "$base_dir" "base-due" '#!/usr/bin/env bash' 'DOTTY_CLEANUP_RETIRE_AFTER="2000-01-01"'
    add_cleanup_dir "$overlay_dir" "overlay-due" '#!/usr/bin/env bash' 'DOTTY_CLEANUP_RETIRE_AFTER="2000-01-01"'
    register_test_repo "base" "$base_dir"
    register_test_repo "overlay" "$overlay_dir"
    mkdir -p "$TEST_DOTTY_DIR/cleanups/base/base-due" "$TEST_DOTTY_DIR/cleanups/overlay/overlay-due"
    : > "$TEST_DOTTY_DIR/cleanups/base/base-due/done"
    : > "$TEST_DOTTY_DIR/cleanups/overlay/overlay-due/done"

    run cmd_cleanups
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"retire  base-due"* ]]
    [[ "$output" == *"retire  overlay-due"* ]]
    [[ "$(printf '%s\n' "$output" | grep -c 'Retirement dates are advisory')" -eq 1 ]]
}

@test "doctor reports malformed cleanup definitions" {
    create_test_repo "dotfiles"
    local repo_dir="$REPLY"
    git -C "$repo_dir" init -q
    mkdir -p "$repo_dir/.dotty/cleanups/bad"
    printf '%s\n' '#!/usr/bin/env bash' > "$repo_dir/.dotty/cleanups/not-executable"
    add_cleanup_dir "$repo_dir" "bad-config" '#!/usr/bin/env bash' 'DOTTY_CLEANUP_UNSUPPORTED=true'
    add_cleanup_dir "$repo_dir" "bad-retirement" '#!/usr/bin/env bash' 'DOTTY_CLEANUP_RETIRE_AFTER="2025-02-29"'
    register_test_repo "dotfiles" "$repo_dir"

    run cmd_doctor
    [[ "$status" -eq 1 ]]
    [[ "$output" == *"cleanup 'bad' is missing run.sh"* ]]
    [[ "$output" == *"cleanup 'not-executable' exists but is not executable"* ]]
    [[ "$output" == *"Unsupported cleanup config variable: DOTTY_CLEANUP_UNSUPPORTED"* ]]
    [[ "$output" == *"cleanup 'bad-retirement' config is invalid: DOTTY_CLEANUP_RETIRE_AFTER must be a valid YYYY-MM-DD date"* ]]
}
