#!/usr/bin/env bats

load test_helper

setup() {
    setup_test_env
    load_dotty
}

teardown() {
    unset DOTTY_DRY_RUN
    teardown_test_env
}

create_git_remote() {
    local name="$1"
    local work_dir="$TEST_HOME/sources/$name"
    local bare_dir="$TEST_HOME/remotes/$name.git"

    mkdir -p "$work_dir"
    git -C "$work_dir" init -q
    git -C "$work_dir" checkout -q -b main
    printf '%s\n' "initial $name" > "$work_dir/value.txt"
    git -C "$work_dir" add value.txt
    git -C "$work_dir" \
        -c user.name="Dotty Tests" \
        -c user.email="dotty-tests@example.com" \
        commit -q -m "initial $name"

    mkdir -p "$(dirname "$bare_dir")"
    git clone --bare -q "$work_dir" "$bare_dir"
    git -C "$bare_dir" symbolic-ref HEAD refs/heads/main
    git -C "$work_dir" remote add origin "$bare_dir"

    REPLY="file://$bare_dir"
    REPLY_WORK="$work_dir"
}

push_git_remote_update() {
    local work_dir="$1"
    local content="$2"

    printf '%s\n' "$content" > "$work_dir/value.txt"
    git -C "$work_dir" add value.txt
    git -C "$work_dir" \
        -c user.name="Dotty Tests" \
        -c user.email="dotty-tests@example.com" \
        commit -q -m "$content"
    git -C "$work_dir" push -q origin main
}

write_manifest() {
    local repo_dir="$1"
    shift

    mkdir -p "$repo_dir/.dotty"
    {
        printf '# name\trepo-url\tbranch\tcheckout\tupdate\tinstall\n'
        printf '%s\n' "$@"
    } > "$repo_dir/.dotty/managed-checkouts.tsv"
}

@test "checkouts succeeds when the active chain has no manifests" {
    create_test_repo "dotfiles"
    local repo_dir="$REPLY"
    register_test_repo "dotfiles" "$repo_dir"

    run cmd_checkouts

    [[ "$status" -eq 0 ]]
    [[ -z "$output" ]]
}

@test "checkouts dry-run discovers layered manifests in chain order and skips duplicate names" {
    create_git_remote "alpha"
    local alpha_url="$REPLY"
    create_git_remote "beta"
    local beta_url="$REPLY"

    create_test_repo "base"
    local base_dir="$REPLY"
    create_test_repo "overlay" "$base_dir"
    local overlay_dir="$REPLY"

    write_manifest "$base_dir" \
        "alpha"$'\t'"$alpha_url"$'\t'"main"$'\t'"dev"$'\t'"fast-forward"$'\t'
    write_manifest "$overlay_dir" \
        "alpha"$'\t'"$beta_url"$'\t'"main"$'\t'"dev"$'\t'"fast-forward"$'\t' \
        "beta"$'\t'"$beta_url"$'\t'"main"$'\t'"dev"$'\t'"fast-forward"$'\t'

    register_test_repo "base" "$base_dir"
    register_test_repo "overlay" "$overlay_dir"

    export DOTTY_DRY_RUN=true
    run cmd_checkouts

    [[ "$status" -eq 0 ]]
    [[ "$output" == *"Would clone managed checkout alpha"* ]]
    [[ "$output" == *"Would clone managed checkout beta"* ]]
    [[ "$output" == *"managed checkout 'alpha' already defined by base; skipping duplicate in overlay"* ]]
    [[ ! -e "$TEST_HOME/src/alpha" ]]
    [[ ! -e "$TEST_HOME/src/beta" ]]
}

@test "checkouts clones missing rows and fast-forwards clean matching checkouts" {
    create_git_remote "alpha"
    local alpha_url="$REPLY"
    local alpha_work="$REPLY_WORK"

    create_test_repo "dotfiles"
    local repo_dir="$REPLY"
    write_manifest "$repo_dir" \
        "alpha"$'\t'"$alpha_url"$'\t'"main"$'\t'"dev"$'\t'"fast-forward"$'\t'
    register_test_repo "dotfiles" "$repo_dir"

    run cmd_checkouts
    [[ "$status" -eq 0 ]]
    [[ "$(cat "$TEST_HOME/src/alpha/value.txt")" == "initial alpha" ]]

    push_git_remote_update "$alpha_work" "updated alpha"

    run cmd_checkouts
    [[ "$status" -eq 0 ]]
    [[ "$(cat "$TEST_HOME/src/alpha/value.txt")" == "updated alpha" ]]
}

@test "checkouts skips dirty, wrong-origin, wrong-branch, non-git, diverged, and malformed rows with warnings" {
    create_git_remote "alpha"
    local alpha_url="$REPLY"
    local alpha_work="$REPLY_WORK"
    create_git_remote "other"
    local other_url="$REPLY"

    create_test_repo "dotfiles"
    local repo_dir="$REPLY"
    write_manifest "$repo_dir" \
        "dirty"$'\t'"$alpha_url"$'\t'"main"$'\t'"$TEST_HOME/checkouts/dirty"$'\t'"fast-forward"$'\t' \
        "wrong-origin"$'\t'"$alpha_url"$'\t'"main"$'\t'"$TEST_HOME/checkouts/wrong-origin"$'\t'"fast-forward"$'\t' \
        "wrong-branch"$'\t'"$alpha_url"$'\t'"main"$'\t'"$TEST_HOME/checkouts/wrong-branch"$'\t'"fast-forward"$'\t' \
        "non-git"$'\t'"$alpha_url"$'\t'"main"$'\t'"$TEST_HOME/checkouts/non-git"$'\t'"fast-forward"$'\t' \
        "diverged"$'\t'"$alpha_url"$'\t'"main"$'\t'"$TEST_HOME/checkouts/diverged"$'\t'"fast-forward"$'\t' \
        "bad-update"$'\t'"$alpha_url"$'\t'"main"$'\t'"dev"$'\t'"merge"$'\t' \
        "malformed"
    register_test_repo "dotfiles" "$repo_dir"

    mkdir -p "$TEST_HOME/checkouts"
    git clone -q "$alpha_url" "$TEST_HOME/checkouts/dirty"
    printf 'dirty\n' >> "$TEST_HOME/checkouts/dirty/value.txt"
    git clone -q "$other_url" "$TEST_HOME/checkouts/wrong-origin"
    git clone -q "$alpha_url" "$TEST_HOME/checkouts/wrong-branch"
    git -C "$TEST_HOME/checkouts/wrong-branch" checkout -q -b local-work
    mkdir -p "$TEST_HOME/checkouts/non-git"
    git clone -q "$alpha_url" "$TEST_HOME/checkouts/diverged"
    printf 'local\n' > "$TEST_HOME/checkouts/diverged/local.txt"
    git -C "$TEST_HOME/checkouts/diverged" add local.txt
    git -C "$TEST_HOME/checkouts/diverged" \
        -c user.name="Dotty Tests" \
        -c user.email="dotty-tests@example.com" \
        commit -q -m "local"
    push_git_remote_update "$alpha_work" "remote alpha"

    run cmd_checkouts

    [[ "$status" -eq 0 ]]
    [[ "$output" == *"managed checkout 'dirty' has local changes; skipping"* ]]
    [[ "$output" == *"managed checkout 'wrong-origin' origin mismatch; skipping"* ]]
    [[ "$output" == *"managed checkout 'wrong-branch' is on branch local-work, expected main; skipping"* ]]
    [[ "$output" == *"managed checkout 'non-git' exists but is not a git repo; skipping"* ]]
    [[ "$output" == *"managed checkout 'diverged' has diverged from origin/main; skipping"* ]]
    [[ "$output" == *"managed checkout 'bad-update' has unsupported update policy 'merge'; skipping"* ]]
    [[ "$output" == *"malformed managed checkout row; skipping"* ]]
}

@test "checkouts runs repo and dotty install actions with metadata env" {
    create_git_remote "repo-install"
    local repo_url="$REPLY"
    local repo_work="$REPLY_WORK"
    mkdir -p "$repo_work/scripts"
    cat > "$repo_work/scripts/install-record" <<EOF
#!/usr/bin/env bash
set -euo pipefail
{
    pwd
    printf '%s\n' "\$DOTTY_MANAGED_CHECKOUT_NAME"
    printf '%s\n' "\$DOTTY_MANAGED_CHECKOUT_DIR"
    printf '%s\n' "\$DOTTY_MANAGED_CHECKOUT_REPO_URL"
    printf '%s\n' "\$DOTTY_MANAGED_CHECKOUT_BRANCH"
} > "$TEST_HOME/repo-install-record"
EOF
    chmod +x "$repo_work/scripts/install-record"
    git -C "$repo_work" add scripts/install-record
    git -C "$repo_work" \
        -c user.name="Dotty Tests" \
        -c user.email="dotty-tests@example.com" \
        commit -q -m "add repo installer"
    git -C "$repo_work" push -q origin main

    create_git_remote "dotty-install"
    local dotty_url="$REPLY"

    create_test_repo "dotfiles"
    local repo_dir="$REPLY"
    mkdir -p "$repo_dir/scripts"
    cat > "$repo_dir/scripts/install-record" <<EOF
#!/usr/bin/env bash
set -euo pipefail
{
    pwd
    printf '%s\n' "\$DOTTY_MANAGED_CHECKOUT_NAME"
    printf '%s\n' "\$DOTTY_MANAGED_CHECKOUT_DIR"
    printf '%s\n' "\$DOTTY_MANAGED_CHECKOUT_REPO_URL"
    printf '%s\n' "\$DOTTY_MANAGED_CHECKOUT_BRANCH"
} > "$TEST_HOME/dotty-install-record"
EOF
    chmod +x "$repo_dir/scripts/install-record"
    write_manifest "$repo_dir" \
        "repo-install"$'\t'"$repo_url"$'\t'"main"$'\t'"dev"$'\t'"fast-forward"$'\t'"repo:scripts/install-record" \
        "dotty-install"$'\t'"$dotty_url"$'\t'"main"$'\t'"dev"$'\t'"fast-forward"$'\t'"dotty:scripts/install-record"
    register_test_repo "dotfiles" "$repo_dir"

    run cmd_checkouts

    [[ "$status" -eq 0 ]]
    [[ "$(cat "$TEST_HOME/repo-install-record")" == "$TEST_HOME/src/repo-install"$'\n'"repo-install"$'\n'"$TEST_HOME/src/repo-install"$'\n'"$repo_url"$'\n'"main" ]]
    [[ "$(cat "$TEST_HOME/dotty-install-record")" == "$repo_dir"$'\n'"dotty-install"$'\n'"$TEST_HOME/src/dotty-install"$'\n'"$dotty_url"$'\n'"main" ]]
}

@test "checkouts reports installer failures but continues remaining rows" {
    create_git_remote "fail-install"
    local fail_url="$REPLY"
    local fail_work="$REPLY_WORK"
    mkdir -p "$fail_work/scripts"
    cat > "$fail_work/scripts/fail" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exit 23
EOF
    chmod +x "$fail_work/scripts/fail"
    git -C "$fail_work" add scripts/fail
    git -C "$fail_work" \
        -c user.name="Dotty Tests" \
        -c user.email="dotty-tests@example.com" \
        commit -q -m "add failing installer"
    git -C "$fail_work" push -q origin main

    create_git_remote "after-fail"
    local ok_url="$REPLY"

    create_test_repo "dotfiles"
    local repo_dir="$REPLY"
    mkdir -p "$repo_dir/scripts"
    cat > "$repo_dir/scripts/ok" <<EOF
#!/usr/bin/env bash
set -euo pipefail
touch "$TEST_HOME/after-fail-installed"
EOF
    chmod +x "$repo_dir/scripts/ok"
    write_manifest "$repo_dir" \
        "fail-install"$'\t'"$fail_url"$'\t'"main"$'\t'"dev"$'\t'"fast-forward"$'\t'"repo:scripts/fail" \
        "after-fail"$'\t'"$ok_url"$'\t'"main"$'\t'"dev"$'\t'"fast-forward"$'\t'"dotty:scripts/ok"
    register_test_repo "dotfiles" "$repo_dir"

    run cmd_checkouts

    [[ "$status" -ne 0 ]]
    [[ "$output" == *"managed checkout 'fail-install' install action failed (exit 23)"* ]]
    [[ -e "$TEST_HOME/after-fail-installed" ]]
}

@test "managed checkout git wrapper disables interactive prompts" {
    git() {
        printf 'prompt=%s askpass=%s args=%s\n' "${GIT_TERMINAL_PROMPT:-}" "${GIT_ASKPASS+x}" "$*"
    }

    run _managed_checkout_git fetch origin main

    [[ "$status" -eq 0 ]]
    [[ "$output" == "prompt=0 askpass=x args=fetch origin main" ]]
}

@test "run_chain syncs managed checkouts after pulls and before repo processing" {
    create_test_repo "base"
    local base_dir="$REPLY"
    create_test_repo "overlay" "$base_dir"
    local overlay_dir="$REPLY"

    CHAIN_NAMES=("base" "overlay")
    CHAIN_PATHS=("$base_dir" "$overlay_dir")

    pull_if_clean() {
        printf 'pull:%s\n' "$(basename "$1")"
    }

    sync_managed_checkouts() {
        printf 'checkouts:%s\n' "$1"
    }

    process_repo() {
        printf 'process:%s:%s\n' "$(basename "$1")" "$3"
    }

    run run_chain "true" "update"

    [[ "$status" -eq 0 ]]
    [[ "$output" == $'pull:base\npull:overlay\ncheckouts:update\nprocess:base:update\nprocess:overlay:update' ]]
}

@test "main serializes checkouts through the operation lock" {
    cmd_checkouts() {
        if [[ -d "$DOTTY_DIR/operation.lock" ]]; then
            printf 'locked\n'
        else
            printf 'unlocked\n'
        fi
    }

    run main checkouts

    [[ "$status" -eq 0 ]]
    [[ "$output" == "locked" ]]
    [[ ! -e "$DOTTY_DIR/operation.lock" ]]
}
