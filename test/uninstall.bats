#!/usr/bin/env bats

load test_helper

setup() {
    setup_test_env
    load_dotty
}

teardown() {
    teardown_test_env
}

@test "uninstall removes symlinks pointing into repo" {
    create_test_repo "test-repo"
    local repo_dir="$REPLY"

    add_repo_file "$repo_dir" ".bashrc" "# bashrc"
    add_repo_file "$repo_dir" ".vimrc" "set nocompatible"

    create_symlinks_from_dir "$repo_dir/home" "$TEST_HOME"
    registry_set "test-repo" "$repo_dir"

    [[ -L "$TEST_HOME/.bashrc" ]]
    [[ -L "$TEST_HOME/.vimrc" ]]

    cmd_uninstall "test-repo"

    [[ ! -L "$TEST_HOME/.bashrc" ]]
    [[ ! -L "$TEST_HOME/.vimrc" ]]
    [[ ! -e "$TEST_HOME/.bashrc" ]]
    [[ ! -e "$TEST_HOME/.vimrc" ]]
}

@test "uninstall restores backed-up files" {
    create_test_repo "test-repo"
    local repo_dir="$REPLY"

    add_repo_file "$repo_dir" ".bashrc" "# repo version"

    # Create a backup (simulating what dotty does when it links over an existing file)
    mkdir -p "$DOTTY_BACKUPS_DIR"
    echo "# original version" > "$DOTTY_BACKUPS_DIR/.bashrc"

    create_symlinks_from_dir "$repo_dir/home" "$TEST_HOME"
    registry_set "test-repo" "$repo_dir"

    [[ -L "$TEST_HOME/.bashrc" ]]

    cmd_uninstall "test-repo"

    [[ ! -L "$TEST_HOME/.bashrc" ]]
    [[ -f "$TEST_HOME/.bashrc" ]]
    [[ "$(cat "$TEST_HOME/.bashrc")" == "# original version" ]]
}

@test "uninstall unregisters the repo" {
    create_test_repo "test-repo"
    local repo_dir="$REPLY"

    add_repo_file "$repo_dir" ".bashrc" "# bashrc"

    create_symlinks_from_dir "$repo_dir/home" "$TEST_HOME"
    registry_set "test-repo" "$repo_dir"

    cmd_uninstall "test-repo"

    # Should no longer be in the registry
    ! grep -q "^test-repo=" "$DOTTY_REGISTRY"
}

@test "uninstall leaves symlinks from other repos intact" {
    create_test_repo "repo-a"
    local repo_a="$REPLY"
    add_repo_file "$repo_a" ".bashrc" "# from a"

    create_test_repo "repo-b"
    local repo_b="$REPLY"
    add_repo_file "$repo_b" ".vimrc" "# from b"

    create_symlinks_from_dir "$repo_a/home" "$TEST_HOME"
    create_symlinks_from_dir "$repo_b/home" "$TEST_HOME"
    registry_set "repo-a" "$repo_a"
    registry_set "repo-b" "$repo_b"

    cmd_uninstall "repo-a"

    # repo-a's symlink should be gone
    [[ ! -L "$TEST_HOME/.bashrc" ]]

    # repo-b's symlink should remain
    [[ -L "$TEST_HOME/.vimrc" ]]
    [[ "$(readlink "$TEST_HOME/.vimrc")" == "$repo_b/home/.vimrc" ]]
}

@test "uninstall removes nested symlinks from exploded directories" {
    create_test_repo "repo-a"
    local repo_a="$REPLY"
    add_repo_file "$repo_a" ".config/git/config" "[core]\neditor = vim"

    create_test_repo "repo-b"
    local repo_b="$REPLY"
    add_repo_file "$repo_b" ".config/git/ignore" "*.swp"

    # Link both repos (causes directory explosion for .config/git)
    create_symlinks_from_dir "$repo_a/home" "$TEST_HOME"
    create_symlinks_from_dir "$repo_b/home" "$TEST_HOME"
    registry_set "repo-a" "$repo_a"
    registry_set "repo-b" "$repo_b"

    # Both should be linked in the exploded directory
    [[ -L "$TEST_HOME/.config/git/config" ]]
    [[ -L "$TEST_HOME/.config/git/ignore" ]]

    cmd_uninstall "repo-a"

    # repo-a's file should be gone
    [[ ! -L "$TEST_HOME/.config/git/config" ]]

    # repo-b's file should remain
    [[ -L "$TEST_HOME/.config/git/ignore" ]]
    [[ "$(readlink "$TEST_HOME/.config/git/ignore")" == "$repo_b/home/.config/git/ignore" ]]
}

@test "uninstall fails for unknown repo" {
    run cmd_uninstall "nonexistent"
    [[ "$status" -ne 0 ]]
    [[ "$output" == *"Unknown repo"* ]]
}

@test "uninstall dry-run does not remove symlinks or unregister" {
    create_test_repo "test-repo"
    local repo_dir="$REPLY"

    add_repo_file "$repo_dir" ".bashrc" "# bashrc"

    create_symlinks_from_dir "$repo_dir/home" "$TEST_HOME"
    registry_set "test-repo" "$repo_dir"

    DOTTY_DRY_RUN=true
    run cmd_uninstall "test-repo"
    DOTTY_DRY_RUN=false

    # Symlink should still exist
    [[ -L "$TEST_HOME/.bashrc" ]]

    # Repo should still be registered
    local path
    path="$(registry_get "test-repo")"
    [[ -n "$path" ]]
}

@test "uninstall reports counts" {
    create_test_repo "test-repo"
    local repo_dir="$REPLY"

    add_repo_file "$repo_dir" ".bashrc" "# bashrc"
    add_repo_file "$repo_dir" ".vimrc" "set nocompatible"

    create_symlinks_from_dir "$repo_dir/home" "$TEST_HOME"
    registry_set "test-repo" "$repo_dir"

    run cmd_uninstall "test-repo"
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"2 symlink(s) removed"* ]]
}
