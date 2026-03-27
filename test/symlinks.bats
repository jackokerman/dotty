#!/usr/bin/env bats

load test_helper

setup() {
    setup_test_env
    load_utils
}

teardown() {
    teardown_test_env
}

# create_symlink

@test "create_symlink creates a new symlink" {
    local source_file="$TEST_HOME/source/file.txt"
    mkdir -p "$(dirname "$source_file")"
    echo "hello" > "$source_file"

    local target="$TEST_HOME/linked-file.txt"
    run create_symlink "$source_file" "$target"
    [[ "$status" -eq 0 ]]
    [[ -L "$target" ]]
    [[ "$(readlink "$target")" == "$source_file" ]]
}

@test "create_symlink skips when already correct" {
    local source_file="$TEST_HOME/source/file.txt"
    mkdir -p "$(dirname "$source_file")"
    echo "hello" > "$source_file"

    local target="$TEST_HOME/linked-file.txt"
    ln -s "$source_file" "$target"

    run create_symlink "$source_file" "$target"
    [[ "$status" -eq 0 ]]
    # Should report skipping (increments _SKIP_COUNT internally)
    [[ -L "$target" ]]
    [[ "$(readlink "$target")" == "$source_file" ]]
}

@test "create_symlink updates when pointing elsewhere" {
    local old_source="$TEST_HOME/source/old.txt"
    local new_source="$TEST_HOME/source/new.txt"
    mkdir -p "$(dirname "$old_source")"
    echo "old" > "$old_source"
    echo "new" > "$new_source"

    local target="$TEST_HOME/linked.txt"
    ln -s "$old_source" "$target"

    run create_symlink "$new_source" "$target"
    [[ "$status" -eq 0 ]]
    [[ -L "$target" ]]
    [[ "$(readlink "$target")" == "$new_source" ]]
}

@test "create_symlink backs up existing regular file" {
    local source_file="$TEST_HOME/source/file.txt"
    mkdir -p "$(dirname "$source_file")"
    echo "source" > "$source_file"

    local target="$TEST_HOME/existing.txt"
    echo "original" > "$target"

    run create_symlink "$source_file" "$target"
    [[ "$status" -eq 0 ]]
    [[ -L "$target" ]]

    # Original file should be backed up
    [[ -f "$DOTTY_BACKUPS_DIR/existing.txt" ]]
    [[ "$(cat "$DOTTY_BACKUPS_DIR/existing.txt")" == "original" ]]
}

# create_symlinks_from_dir

@test "create_symlinks_from_dir links files from source to target" {
    create_test_repo "test-repo"
    local repo_dir="$REPLY"

    add_repo_file "$repo_dir" ".bashrc" "# my bashrc"
    add_repo_file "$repo_dir" ".vimrc" "set nocompatible"

    create_symlinks_from_dir "$repo_dir/home" "$TEST_HOME"

    [[ -L "$TEST_HOME/.bashrc" ]]
    [[ "$(readlink "$TEST_HOME/.bashrc")" == "$repo_dir/home/.bashrc" ]]
    [[ -L "$TEST_HOME/.vimrc" ]]
    [[ "$(readlink "$TEST_HOME/.vimrc")" == "$repo_dir/home/.vimrc" ]]
}

@test "create_symlinks_from_dir symlinks whole nested dir when target is empty" {
    create_test_repo "test-repo"
    local repo_dir="$REPLY"

    add_repo_file "$repo_dir" ".config/git/config" "[user]\n\tname = test"
    add_repo_file "$repo_dir" ".config/git/ignore" "*.swp"

    create_symlinks_from_dir "$repo_dir/home" "$TEST_HOME"

    # When the target directory doesn't exist yet, dotty symlinks the whole
    # parent directory rather than recursing. This is correct behavior:
    # directory explosion only happens when a second repo needs to merge.
    [[ -L "$TEST_HOME/.config" ]]
    [[ "$(readlink "$TEST_HOME/.config")" == "$repo_dir/home/.config" ]]
}

@test "create_symlinks_from_dir recurses into existing target directories" {
    create_test_repo "test-repo"
    local repo_dir="$REPLY"

    add_repo_file "$repo_dir" ".config/git/config" "[user]\n\tname = test"

    # Pre-create .config so dotty recurses into it
    mkdir -p "$TEST_HOME/.config"

    create_symlinks_from_dir "$repo_dir/home" "$TEST_HOME"

    [[ -d "$TEST_HOME/.config" ]]
    [[ ! -L "$TEST_HOME/.config" ]]
    [[ -L "$TEST_HOME/.config/git" ]]
    [[ "$(readlink "$TEST_HOME/.config/git")" == "$repo_dir/home/.config/git" ]]
}

@test "create_symlinks_from_dir excludes dotty files" {
    create_test_repo "test-repo"
    local repo_dir="$REPLY"

    # These should all be excluded
    echo "readme" > "$repo_dir/home/README.md"
    echo "license" > "$repo_dir/home/LICENSE"
    echo "dsstore" > "$repo_dir/home/.DS_Store"

    # This should be linked
    add_repo_file "$repo_dir" ".bashrc" "# bashrc"

    create_symlinks_from_dir "$repo_dir/home" "$TEST_HOME"

    [[ -L "$TEST_HOME/.bashrc" ]]
    [[ ! -L "$TEST_HOME/README.md" ]]
    [[ ! -L "$TEST_HOME/LICENSE" ]]
    [[ ! -L "$TEST_HOME/.DS_Store" ]]
}

@test "create_symlinks_from_dir respects DOTTY_LINK_IGNORE" {
    create_test_repo "test-repo"
    local repo_dir="$REPLY"

    add_repo_file "$repo_dir" ".config/app/settings.json" '{"key": "value"}'
    add_repo_file "$repo_dir" ".config/app/other.txt" "other"

    DOTTY_LINK_IGNORE=(".config/app/settings.json")

    # Pre-create target dirs so dotty recurses into them
    # (otherwise it symlinks .config as a whole directory)
    mkdir -p "$TEST_HOME/.config/app"

    create_symlinks_from_dir "$repo_dir/home" "$TEST_HOME"

    [[ ! -L "$TEST_HOME/.config/app/settings.json" ]]
    [[ -L "$TEST_HOME/.config/app/other.txt" ]]
}

@test "create_symlinks_from_dir skips gitignored files" {
    create_test_repo "test-repo"
    local repo_dir="$REPLY"

    # Initialize a git repo so git check-ignore works
    git -C "$repo_dir" init -q

    # Add a .gitignore in a subdirectory
    mkdir -p "$repo_dir/home/.config/zsh"
    echo ".zcompdump" > "$repo_dir/home/.config/zsh/.gitignore"
    echo ".zsh_history" >> "$repo_dir/home/.config/zsh/.gitignore"

    # Create gitignored files (simulating zsh writing through symlinks)
    echo "dump" > "$repo_dir/home/.config/zsh/.zcompdump"
    echo "history" > "$repo_dir/home/.config/zsh/.zsh_history"

    # Create a tracked file that should still be linked
    echo "# zshrc" > "$repo_dir/home/.config/zsh/.zshrc"

    # Pre-create target dirs so dotty recurses
    mkdir -p "$TEST_HOME/.config/zsh"

    create_symlinks_from_dir "$repo_dir/home" "$TEST_HOME"

    # Tracked file should be linked
    [[ -L "$TEST_HOME/.config/zsh/.zshrc" ]]

    # Gitignored files should NOT be linked
    [[ ! -L "$TEST_HOME/.config/zsh/.zcompdump" ]]
    [[ ! -L "$TEST_HOME/.config/zsh/.zsh_history" ]]
}

@test "create_symlinks_from_dir links all files when repo has no git dir" {
    create_test_repo "test-repo"
    local repo_dir="$REPLY"

    # No git init — repo is not a git repository
    add_repo_file "$repo_dir" ".bashrc" "# bashrc"
    add_repo_file "$repo_dir" ".profile" "# profile"

    create_symlinks_from_dir "$repo_dir/home" "$TEST_HOME"

    # Both should be linked (gitignore check is a no-op without .git)
    [[ -L "$TEST_HOME/.bashrc" ]]
    [[ -L "$TEST_HOME/.profile" ]]
}

# _explode_dir_symlink

@test "_explode_dir_symlink converts dir symlink to real dir with child symlinks" {
    # Create a source directory with files
    local source_dir="$TEST_HOME/source-dir"
    mkdir -p "$source_dir"
    echo "file1" > "$source_dir/a.txt"
    echo "file2" > "$source_dir/b.txt"

    # Create a symlink to that directory
    local target="$TEST_HOME/linked-dir"
    ln -s "$source_dir" "$target"
    [[ -L "$target" ]]

    _explode_dir_symlink "$target"

    # Should now be a real directory, not a symlink
    [[ -d "$target" ]]
    [[ ! -L "$target" ]]

    # Children should be symlinks to originals
    [[ -L "$target/a.txt" ]]
    [[ -L "$target/b.txt" ]]
    [[ "$(readlink "$target/a.txt")" == "$source_dir/a.txt" ]]
    [[ "$(readlink "$target/b.txt")" == "$source_dir/b.txt" ]]
}

@test "directory merging: two repos contribute to same directory" {
    create_test_repo "base-repo"
    local base_dir="$REPLY"
    add_repo_file "$base_dir" ".config/git/config" "[core]\neditor = vim"

    create_test_repo "overlay-repo"
    local overlay_dir="$REPLY"
    add_repo_file "$overlay_dir" ".config/git/ignore" "*.swp"

    # Link base first, then overlay (simulating chain order)
    create_symlinks_from_dir "$base_dir/home" "$TEST_HOME"
    create_symlinks_from_dir "$overlay_dir/home" "$TEST_HOME"

    # Both files should exist as symlinks
    [[ -L "$TEST_HOME/.config/git/config" ]]
    [[ -L "$TEST_HOME/.config/git/ignore" ]]
    [[ "$(readlink "$TEST_HOME/.config/git/config")" == "$base_dir/home/.config/git/config" ]]
    [[ "$(readlink "$TEST_HOME/.config/git/ignore")" == "$overlay_dir/home/.config/git/ignore" ]]

    # .config/git should be a real directory (not a symlink)
    [[ -d "$TEST_HOME/.config/git" ]]
    [[ ! -L "$TEST_HOME/.config/git" ]]
}

@test "directory merging: overlay file overrides base file" {
    create_test_repo "base-repo"
    local base_dir="$REPLY"
    add_repo_file "$base_dir" ".config/app/settings.txt" "base settings"

    create_test_repo "overlay-repo"
    local overlay_dir="$REPLY"
    add_repo_file "$overlay_dir" ".config/app/settings.txt" "overlay settings"

    create_symlinks_from_dir "$base_dir/home" "$TEST_HOME"
    create_symlinks_from_dir "$overlay_dir/home" "$TEST_HOME"

    # Overlay should win
    [[ -L "$TEST_HOME/.config/app/settings.txt" ]]
    [[ "$(readlink "$TEST_HOME/.config/app/settings.txt")" == "$overlay_dir/home/.config/app/settings.txt" ]]
}

# cleanup_orphans

@test "cleanup_orphans removes dangling symlink pointing into repo" {
    create_test_repo "test-repo"
    local repo_dir="$REPLY"

    add_repo_file "$repo_dir" ".bashrc" "# bashrc"
    add_repo_file "$repo_dir" ".vimrc" "set nocompatible"

    create_symlinks_from_dir "$repo_dir/home" "$TEST_HOME"
    [[ -L "$TEST_HOME/.bashrc" ]]
    [[ -L "$TEST_HOME/.vimrc" ]]

    # Remove the source file (simulating a file removed from the repo)
    rm "$repo_dir/home/.vimrc"

    cleanup_orphans "$repo_dir/home" "$TEST_HOME"

    # .vimrc should be removed (orphan), .bashrc should remain
    [[ ! -L "$TEST_HOME/.vimrc" ]]
    [[ -L "$TEST_HOME/.bashrc" ]]
}

@test "cleanup_orphans ignores symlinks pointing to other repos" {
    create_test_repo "repo-a"
    local repo_a="$REPLY"
    add_repo_file "$repo_a" ".bashrc" "# from a"

    create_test_repo "repo-b"
    local repo_b="$REPLY"
    add_repo_file "$repo_b" ".vimrc" "# from b"

    create_symlinks_from_dir "$repo_a/home" "$TEST_HOME"
    create_symlinks_from_dir "$repo_b/home" "$TEST_HOME"

    # Remove source from repo-a
    rm "$repo_a/home/.bashrc"

    # Only clean orphans for repo-b (should not touch repo-a's dangling link)
    cleanup_orphans "$repo_b/home" "$TEST_HOME"

    # repo-a's orphan should still exist (we didn't clean repo-a)
    [[ -L "$TEST_HOME/.bashrc" ]]
    [[ -L "$TEST_HOME/.vimrc" ]]
}

@test "cleanup_orphans recurses into real directories" {
    create_test_repo "test-repo"
    local repo_dir="$REPLY"

    add_repo_file "$repo_dir" ".config/app/settings.txt" "settings"
    add_repo_file "$repo_dir" ".config/app/other.txt" "other"

    # Pre-create target dirs so dotty recurses
    mkdir -p "$TEST_HOME/.config/app"

    create_symlinks_from_dir "$repo_dir/home" "$TEST_HOME"
    [[ -L "$TEST_HOME/.config/app/settings.txt" ]]
    [[ -L "$TEST_HOME/.config/app/other.txt" ]]

    # Remove one source file
    rm "$repo_dir/home/.config/app/settings.txt"

    cleanup_orphans "$repo_dir/home" "$TEST_HOME"

    [[ ! -L "$TEST_HOME/.config/app/settings.txt" ]]
    [[ -L "$TEST_HOME/.config/app/other.txt" ]]
}

@test "cleanup_orphans is a no-op when nothing is orphaned" {
    create_test_repo "test-repo"
    local repo_dir="$REPLY"

    add_repo_file "$repo_dir" ".bashrc" "# bashrc"

    create_symlinks_from_dir "$repo_dir/home" "$TEST_HOME"

    run cleanup_orphans "$repo_dir/home" "$TEST_HOME"
    [[ "$status" -eq 0 ]]
    # Should not print anything about removing orphans
    [[ "$output" != *"orphan"* ]]
    [[ -L "$TEST_HOME/.bashrc" ]]
}
