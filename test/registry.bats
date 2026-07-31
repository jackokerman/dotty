#!/usr/bin/env bats

load test_helper

setup() {
    setup_test_env
    load_dotty
}

teardown() {
    teardown_test_env
}

@test "registry_set appends a new entry" {
    echo "existing=/path/to/existing" > "$TEST_REGISTRY"

    registry_set "my-repo" "/path/to/repo"

    run diff -u <(printf '%s\n' \
        "existing=/path/to/existing" \
        "my-repo=/path/to/repo") "$TEST_REGISTRY"
    [[ "$status" -eq 0 ]]
}

@test "registry_get retrieves an existing entry" {
    echo "my-repo=/path/to/repo" > "$TEST_REGISTRY"
    run registry_get "my-repo"
    [[ "$status" -eq 0 ]]
    [[ "$output" == "/path/to/repo" ]]
}

@test "registry_get returns empty for missing entry" {
    run registry_get "nonexistent"
    [[ "$status" -ne 0 ]]
    [[ -z "$output" ]]
}

@test "registry_set updates an existing entry" {
    echo "my-repo=/old/path" > "$TEST_REGISTRY"
    registry_set "my-repo" "/new/path"

    run registry_get "my-repo"
    [[ "$output" == "/new/path" ]]

    # Should only have one entry for my-repo
    local count
    count="$(grep -c "^my-repo=" "$TEST_REGISTRY")"
    [[ "$count" -eq 1 ]]
}

@test "registry_set preserves order when updating the first entry" {
    echo "repo-a=/path/a" > "$TEST_REGISTRY"
    echo "repo-b=/path/b" >> "$TEST_REGISTRY"
    echo "repo-c=/path/c" >> "$TEST_REGISTRY"

    registry_set "repo-a" "/new/path/a"

    run diff -u <(printf '%s\n' \
        "repo-a=/new/path/a" \
        "repo-b=/path/b" \
        "repo-c=/path/c") "$TEST_REGISTRY"
    [[ "$status" -eq 0 ]]
}

@test "registry_set preserves order when updating a middle entry" {
    echo "repo-a=/path/a" > "$TEST_REGISTRY"
    echo "repo-b=/path/b" >> "$TEST_REGISTRY"
    echo "repo-c=/path/c" >> "$TEST_REGISTRY"

    registry_set "repo-b" "/new/path/b"

    run diff -u <(printf '%s\n' \
        "repo-a=/path/a" \
        "repo-b=/new/path/b" \
        "repo-c=/path/c") "$TEST_REGISTRY"
    [[ "$status" -eq 0 ]]
}

@test "registry_set collapses duplicate entries at the first match" {
    echo "repo-a=/path/a" > "$TEST_REGISTRY"
    echo "repo-b=/old/path/b" >> "$TEST_REGISTRY"
    echo "repo-c=/path/c" >> "$TEST_REGISTRY"
    echo "repo-b=/duplicate/path/b" >> "$TEST_REGISTRY"

    registry_set "repo-b" "/new/path/b"

    run diff -u <(printf '%s\n' \
        "repo-a=/path/a" \
        "repo-b=/new/path/b" \
        "repo-c=/path/c") "$TEST_REGISTRY"
    [[ "$status" -eq 0 ]]
}

@test "registry_remove deletes an entry" {
    echo "repo-a=/path/a" > "$TEST_REGISTRY"
    echo "repo-b=/path/b" >> "$TEST_REGISTRY"

    registry_remove "repo-a"

    run registry_get "repo-a"
    [[ -z "$output" ]]
    run registry_get "repo-b"
    [[ "$output" == "/path/b" ]]
}

@test "registry_remove is safe on missing entry" {
    echo "repo-a=/path/a" > "$TEST_REGISTRY"
    registry_remove "nonexistent"

    run registry_get "repo-a"
    [[ "$output" == "/path/a" ]]
}

@test "registry_names lists all registered names" {
    echo "repo-a=/path/a" > "$TEST_REGISTRY"
    echo "repo-b=/path/b" >> "$TEST_REGISTRY"

    run registry_names
    [[ "$status" -eq 0 ]]
    [[ "${lines[0]}" == "repo-a" ]]
    [[ "${lines[1]}" == "repo-b" ]]
}

@test "registry_names returns empty for empty registry" {
    > "$TEST_REGISTRY"
    run registry_names
    [[ -z "$output" ]]
}
