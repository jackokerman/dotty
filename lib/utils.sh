#!/usr/bin/env bash
# Shared utility library for dotty and hook scripts.
# Source this in a hook: source "$DOTTY_LIB"

# Double-source guard
[[ -n "${_DOTTY_LIB_LOADED:-}" ]] && return 0
_DOTTY_LIB_LOADED=1

# Logging

COLOR_MAGENTA="\033[35m"
COLOR_BLUE="\033[34m"
COLOR_GREEN="\033[32m"
COLOR_RED="\033[31m"
COLOR_YELLOW="\033[33m"
# shellcheck disable=SC2034
COLOR_DIM="\033[2m"
COLOR_BOLD="\033[1m"
COLOR_NONE="\033[0m"

# Respect NO_COLOR (https://no-color.org) and disable colors when not a TTY
if [[ -n "${NO_COLOR:-}" ]] || [[ ! -t 1 ]]; then
    COLOR_MAGENTA="" COLOR_BLUE="" COLOR_GREEN="" COLOR_RED="" COLOR_YELLOW=""
    COLOR_DIM="" COLOR_BOLD="" COLOR_NONE=""
fi

title()   { echo -e "${COLOR_MAGENTA}${COLOR_BOLD}● $1${COLOR_NONE}"; }
info()    { echo -e "· $1"; }
success() { echo -e "${COLOR_GREEN}✔ $1${COLOR_NONE}"; }
warning() { echo -e "${COLOR_YELLOW}⚠ $1${COLOR_NONE}" >&2; }
die()     { echo -e "${COLOR_RED}✖ $1${COLOR_NONE}" >&2; exit 1; }

verbose_info() {
    if [[ "${DOTTY_VERBOSE:-false}" == "true" ]]; then
        info "$1"
    fi
}

# Symlink functions

DOTTY_BACKUPS_DIR="${DOTTY_BACKUPS_DIR:-$HOME/.dotty/backups}"
DOTTY_VERBOSE="${DOTTY_VERBOSE:-false}"
_SKIP_COUNT="${_SKIP_COUNT:-0}"
_LINK_FAIL_COUNT="${_LINK_FAIL_COUNT:-0}"
_LINK_DEPTH="${_LINK_DEPTH:-0}"

EXCLUDE_PATTERNS=(
    .git .gitignore .gitmodules
    README.md LICENSE
    install.sh .dotty
    .DS_Store
)

should_exclude() {
    local name="$1"
    for pattern in "${EXCLUDE_PATTERNS[@]}"; do
        [[ "$name" == "$pattern" ]] && return 0
    done
    return 1
}

_is_link_ignored() {
    local rel_path="$1"
    [[ -z "${DOTTY_LINK_IGNORE+x}" || ${#DOTTY_LINK_IGNORE[@]} -eq 0 ]] && return 1
    for pattern in "${DOTTY_LINK_IGNORE[@]}"; do
        [[ "$rel_path" == "$pattern" ]] && return 0
    done
    return 1
}

# Remove symlinks in target_dir that point into source_dir but whose source
# no longer exists. Scans target_dir's top-level entries for symlinks pointing
# into source_dir, and for real directories, recurses only into subdirectories
# where the corresponding source directory also exists (meaning dotty might
# have linked individual files inside).
_ORPHAN_COUNT=0

_cleanup_orphans_in() {
    local source_dir="$1"
    local target_dir="$2"

    [[ -d "$target_dir" ]] || return 0

    local item
    for item in "$target_dir"/* "$target_dir"/.*; do
        [[ -e "$item" || -L "$item" ]] || continue
        local name
        name="$(basename "$item")"
        [[ "$name" == "." || "$name" == ".." ]] && continue

        if [[ -L "$item" ]]; then
            local link_target
            link_target="$(readlink "$item")"
            if [[ "$link_target" == "$source_dir"/* || "$link_target" == "$source_dir" ]]; then
                if [[ ! -e "$item" ]]; then
                    if [[ "${DOTTY_DRY_RUN:-false}" == "true" ]]; then
                        info "[dry-run] Would remove orphan: ~${item#"$HOME"}"
                    else
                        rm "$item"
                        verbose_info "Removed orphan: ~${item#"$HOME"}"
                    fi
                    _ORPHAN_COUNT=$((_ORPHAN_COUNT + 1))
                fi
            fi
        elif [[ -d "$item" && ! -L "$item" && -d "$source_dir/$name" ]]; then
            # Recurse into real dirs that have a corresponding source directory
            _cleanup_orphans_in "$source_dir/$name" "$item"
        fi
    done
}

cleanup_orphans() {
    local source_dir="$1"
    local target_dir="$2"

    _ORPHAN_COUNT=0
    _cleanup_orphans_in "$source_dir" "$target_dir"
    if [[ $_ORPHAN_COUNT -gt 0 ]]; then
        info "Removed $_ORPHAN_COUNT orphan symlink(s)"
    fi
}

# Remove symlinks in target_dir that point into source_dir, and restore
# backups where available. Used by uninstall to cleanly tear down a repo.
_UNLINK_COUNT=0
_RESTORE_COUNT=0

_remove_repo_symlinks_in() {
    local source_dir="$1"
    local target_dir="$2"

    [[ -d "$target_dir" ]] || return 0

    local item
    for item in "$target_dir"/* "$target_dir"/.*; do
        [[ -e "$item" || -L "$item" ]] || continue
        local name
        name="$(basename "$item")"
        [[ "$name" == "." || "$name" == ".." ]] && continue

        if [[ -L "$item" ]]; then
            local link_target
            link_target="$(readlink "$item")"
            if [[ "$link_target" == "$source_dir"/* || "$link_target" == "$source_dir" ]]; then
                local rel="${item#"$HOME"/}"
                local backup="$DOTTY_BACKUPS_DIR/$rel"
                if [[ "${DOTTY_DRY_RUN:-false}" == "true" ]]; then
                    if [[ -e "$backup" ]]; then
                        info "[dry-run] Would restore: ~/$rel (from backup)"
                    else
                        info "[dry-run] Would remove: ~/$rel"
                    fi
                else
                    rm "$item"
                    if [[ -e "$backup" ]]; then
                        mv "$backup" "$item"
                        verbose_info "Restored: ~/$rel (from backup)"
                        _RESTORE_COUNT=$((_RESTORE_COUNT + 1))
                    else
                        verbose_info "Removed: ~/$rel"
                    fi
                fi
                _UNLINK_COUNT=$((_UNLINK_COUNT + 1))
            fi
        elif [[ -d "$item" && ! -L "$item" && -d "$source_dir/$name" ]]; then
            _remove_repo_symlinks_in "$source_dir/$name" "$item"
        fi
    done
}

remove_repo_symlinks() {
    local source_dir="$1"
    local target_dir="$2"

    _UNLINK_COUNT=0
    _RESTORE_COUNT=0
    _remove_repo_symlinks_in "$source_dir" "$target_dir"
}

create_symlink() {
    local source="$1"
    local target="$2"

    if [[ -L "$target" ]]; then
        local current
        current="$(readlink "$target")"
        if [[ "$current" == "$source" ]]; then
            _SKIP_COUNT=$((_SKIP_COUNT + 1))
            if [[ "$DOTTY_VERBOSE" == "true" ]]; then
                info "~${target#"$HOME"} already linked... Skipping."
            fi
            return 0
        else
            if [[ "${DOTTY_DRY_RUN:-false}" == "true" ]]; then
                info "[dry-run] Would update: ~${target#"$HOME"}"
                return 0
            fi
            info "Updating symlink: ~${target#"$HOME"}"
            rm "$target"
        fi
    elif [[ -e "$target" ]]; then
        if [[ "${DOTTY_DRY_RUN:-false}" == "true" ]]; then
            info "[dry-run] Would backup and link: ~${target#"$HOME"}"
            return 0
        fi
        local rel="${target#"$HOME"/}"
        local backup="$DOTTY_BACKUPS_DIR/$rel"
        mkdir -p "$(dirname "$backup")"
        mv "$target" "$backup"
        warning "Backed up ~${target#"$HOME"} → ~/.dotty/backups/$rel"
    elif [[ "${DOTTY_DRY_RUN:-false}" == "true" ]]; then
        info "[dry-run] Would link: ~${target#"$HOME"}"
        return 0
    fi

    if ln -s "$source" "$target"; then
        success "Linked: ~${target#"$HOME"}"
        _DOTTY_CHANGES_MADE=true
    else
        warning "Failed to link: ~${target#"$HOME"}"
        _LINK_FAIL_COUNT=$((_LINK_FAIL_COUNT + 1))
        return 1
    fi
}

# Explode a directory symlink into a real directory with symlinks to the
# original contents. This prevents merges from writing into other repos.
_explode_dir_symlink() {
    local target_item="$1"
    local resolved
    resolved="$(readlink "$target_item")"

    # Make resolved path absolute if relative
    if [[ "$resolved" != /* ]]; then
        resolved="$(cd "$(dirname "$target_item")" && cd "$(dirname "$resolved")" && pwd)/$(basename "$resolved")"
    fi

    local tmpdir="${target_item}.dotty_tmp"
    mkdir -p "$tmpdir"

    local child
    for child in "$resolved"/* "$resolved"/.*; do
        [[ -e "$child" ]] || continue
        local cname
        cname="$(basename "$child")"
        [[ "$cname" == "." || "$cname" == ".." ]] && continue
        ln -s "$child" "$tmpdir/$cname" 2>/dev/null || true
    done

    rm "$target_item"
    mv "$tmpdir" "$target_item"
}

_link_item() {
    local item="$1"
    local target_item="$2"
    local rel_prefix="${3:-}"
    local name
    name="$(basename "$item")"
    local rel_path="${rel_prefix:+$rel_prefix/}$name"

    if [[ -d "$item" ]]; then
        if [[ -L "$target_item" ]]; then
            local current
            current="$(readlink "$target_item")"
            if [[ "$current" == "$item" ]]; then
                _SKIP_COUNT=$((_SKIP_COUNT + 1))
                if [[ "$DOTTY_VERBOSE" == "true" ]]; then
                    info "~${target_item#"$HOME"} already linked... Skipping."
                fi
            elif [[ -d "$target_item" ]]; then
                _explode_dir_symlink "$target_item"
                create_symlinks_from_dir "$item" "$target_item" "$rel_path"
            else
                info "Updating symlink: ~${target_item#"$HOME"}"
                rm "$target_item"
                create_symlink "$item" "$target_item"
            fi
        elif [[ -d "$target_item" ]]; then
            create_symlinks_from_dir "$item" "$target_item" "$rel_path"
        else
            create_symlink "$item" "$target_item"
        fi
    else
        create_symlink "$item" "$target_item"
    fi
}

create_symlinks_from_dir() {
    local source_dir="$1"
    local target_dir="$2"
    local rel_prefix="${3:-}"

    [[ -d "$source_dir" ]] || return 0

    _LINK_DEPTH=$((_LINK_DEPTH + 1))
    if [[ $_LINK_DEPTH -eq 1 ]]; then
        _SKIP_COUNT=0
    fi

    mkdir -p "$target_dir"

    local item
    for item in "$source_dir"/*; do
        [[ -e "$item" ]] || continue

        local name
        name="$(basename "$item")"

        should_exclude "$name" && continue

        local rel_path="${rel_prefix:+$rel_prefix/}$name"
        _is_link_ignored "$rel_path" && continue

        local target_item="$target_dir/$name"

        _link_item "$item" "$target_item" "$rel_prefix"
    done

    # Also handle hidden files (dotfiles within home/)
    for item in "$source_dir"/.*; do
        [[ -e "$item" ]] || continue
        local name
        name="$(basename "$item")"
        [[ "$name" == "." || "$name" == ".." ]] && continue
        should_exclude "$name" && continue

        local rel_path="${rel_prefix:+$rel_prefix/}$name"
        _is_link_ignored "$rel_path" && continue

        local target_item="$target_dir/$name"
        _link_item "$item" "$target_item" "$rel_prefix"
    done

    _LINK_DEPTH=$((_LINK_DEPTH - 1))
    if [[ $_LINK_DEPTH -eq 0 && $_SKIP_COUNT -gt 0 ]]; then
        info "$_SKIP_COUNT files already linked"
        _SKIP_COUNT=0
    fi
}
