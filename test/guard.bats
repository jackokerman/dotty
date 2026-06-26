#!/usr/bin/env bats

load test_helper

setup() {
    setup_test_env
    load_dotty
}

teardown() {
    teardown_test_env
}

make_git_repo() {
    local repo="$1"

    mkdir -p "$repo"
    git -C "$repo" init -q
    git -C "$repo" config user.email test@example.com
    git -C "$repo" config user.name "Test User"

    printf '# Test\n' > "$repo/README.md"
    git -C "$repo" add README.md
    git -C "$repo" commit -qm 'initial'
}

run_guard_check() {
    local repo="$1"
    shift

    cd "$repo"
    cmd_guard_check "$@"
}

@test "guard-check blocks staged added lines from temporary env patterns" {
    local repo="$TEST_HOME/repo"
    make_git_repo "$repo"

    printf 'This mentions internaltool.\n' >> "$repo/README.md"
    git -C "$repo" add README.md

    export PUBLIC_CONTENT_GUARD_PATTERNS="internaltool"
    run run_guard_check "$repo" --staged README.md
    [[ "$status" -eq 1 ]]
    [[ "$output" == *"Commit blocked"* ]]
    [[ "$output" == *"README.md: +This mentions internaltool."* ]]

    export PUBLIC_CONTENT_GUARD_SKIP=1
    run run_guard_check "$repo" --staged README.md
    [[ "$status" -eq 0 ]]
}

@test "guard-check loads machine-wide repo and explicit pattern files" {
    local repo="$TEST_HOME/repo"
    local extra_patterns="$TEST_HOME/extra-patterns"
    local env_patterns="$TEST_HOME/env-patterns"
    make_git_repo "$repo"

    export XDG_CONFIG_HOME="$TEST_HOME/config"
    mkdir -p "$XDG_CONFIG_HOME/public-content-guard" "$repo/.githooks"
    printf 'usersecret\n' > "$XDG_CONFIG_HOME/public-content-guard/patterns"
    printf 'reposecret\n' > "$repo/.githooks/sensitive-content-patterns"
    printf 'extrasecret\n' > "$extra_patterns"
    printf 'envsecret\n' > "$env_patterns"
    export PUBLIC_CONTENT_GUARD_PATTERN_FILE="$env_patterns"

    printf 'This mentions usersecret.\n' > "$repo/user.md"
    printf 'This mentions reposecret.\n' > "$repo/repo.md"
    printf 'This mentions extrasecret.\n' > "$repo/extra.md"
    printf 'This mentions envsecret.\n' > "$repo/env.md"
    git -C "$repo" add user.md repo.md extra.md env.md

    run run_guard_check "$repo" --staged --patterns-file "$extra_patterns"
    [[ "$status" -eq 1 ]]
    [[ "$output" == *"user.md: +This mentions usersecret."* ]]
    [[ "$output" == *"repo.md: +This mentions reposecret."* ]]
    [[ "$output" == *"extra.md: +This mentions extrasecret."* ]]
    [[ "$output" == *"env.md: +This mentions envsecret."* ]]
}

@test "dotty guard installs hooks that use one shared pattern source" {
    local repo_one="$TEST_HOME/repo-one"
    local repo_two="$TEST_HOME/repo-two"
    local repo_without_hook="$TEST_HOME/repo-without-hook"
    export XDG_CONFIG_HOME="$TEST_HOME/config"
    make_git_repo "$repo_one"
    make_git_repo "$repo_two"
    make_git_repo "$repo_without_hook"
    mkdir -p "$XDG_CONFIG_HOME/public-content-guard"
    printf 'internaltool\n' > "$XDG_CONFIG_HOME/public-content-guard/patterns"

    run "$DOTTY_SCRIPT" guard "$repo_one"
    [[ "$status" -eq 0 ]]
    [[ -x "$repo_one/.git/hooks/pre-commit" ]]
    [[ "$(cat "$repo_one/.git/hooks/pre-commit")" != *"__DOTTY_COMMAND_LITERAL__"* ]]

    run "$DOTTY_SCRIPT" guard "$repo_two"
    [[ "$status" -eq 0 ]]
    [[ -x "$repo_two/.git/hooks/pre-commit" ]]

    printf 'This mentions internaltool.\n' >> "$repo_one/README.md"
    git -C "$repo_one" add README.md
    run git -C "$repo_one" commit -qm 'blocked'
    [[ "$status" -ne 0 ]]
    [[ "$output" == *"Commit blocked"* ]]

    printf 'This mentions internaltool.\n' >> "$repo_two/README.md"
    git -C "$repo_two" add README.md
    run git -C "$repo_two" commit -qm 'blocked'
    [[ "$status" -ne 0 ]]
    [[ "$output" == *"Commit blocked"* ]]

    printf 'This mentions internaltool.\n' >> "$repo_without_hook/README.md"
    git -C "$repo_without_hook" add README.md
    run git -C "$repo_without_hook" commit -qm 'allowed without hook'
    [[ "$status" -eq 0 ]]
}
