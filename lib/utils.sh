#!/usr/bin/env bash
# Shared utility library for dotty and hook scripts.
# Source this in a hook: source "$DOTTY_LIB"

# Double-source guard
[[ -n "${_DOTTY_LIB_LOADED:-}" ]] && return 0
_DOTTY_LIB_LOADED=1

# --- Logging

COLOR_BLUE="\033[34m"
COLOR_GREEN="\033[32m"
COLOR_RED="\033[31m"
COLOR_YELLOW="\033[33m"
# shellcheck disable=SC2034
COLOR_DIM="\033[2m"
COLOR_BOLD="\033[1m"
COLOR_NONE="\033[0m"

title()   { echo -e "${COLOR_BLUE}==>${COLOR_NONE} ${COLOR_BOLD}$1${COLOR_NONE}"; }
info()    { echo -e "$1"; }
success() { echo -e "${COLOR_GREEN}$1${COLOR_NONE}"; }
warning() { echo -e "${COLOR_YELLOW}Warning: ${COLOR_NONE}$1"; }
die()     { echo -e "${COLOR_RED}Error: ${COLOR_NONE}$1" >&2; exit 1; }

verbose_info() {
    if [[ "${DOTTY_VERBOSE:-false}" == "true" ]]; then
        info "$1"
    fi
}

# --- Symlink functions

DOTTY_BACKUPS_DIR="${DOTTY_BACKUPS_DIR:-$HOME/.dotty/backups}"
DOTTY_VERBOSE="${DOTTY_VERBOSE:-false}"
_SKIP_COUNT="${_SKIP_COUNT:-0}"
_LINK_DEPTH="${_LINK_DEPTH:-0}"

EXCLUDE_PATTERNS=(
    .git .gitignore .gitmodules
    README.md LICENSE
    install.sh dotty.conf dotty-run.sh
    .DS_Store
)

should_exclude() {
    local name="$1"
    for pattern in "${EXCLUDE_PATTERNS[@]}"; do
        [[ "$name" == "$pattern" ]] && return 0
    done
    return 1
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
            info "Updating symlink: ~${target#"$HOME"}"
            rm "$target"
        fi
    elif [[ -e "$target" ]]; then
        local rel="${target#"$HOME"/}"
        local backup="$DOTTY_BACKUPS_DIR/$rel"
        mkdir -p "$(dirname "$backup")"
        mv "$target" "$backup"
        warning "Backed up ~${target#"$HOME"} → ~/.dotty/backups/$rel"
    fi

    if ln -s "$source" "$target"; then
        success "Linked: ~${target#"$HOME"}"
    else
        warning "Failed to link: ~${target#"$HOME"}"
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
                create_symlinks_from_dir "$item" "$target_item"
            else
                info "Updating symlink: ~${target_item#"$HOME"}"
                rm "$target_item"
                create_symlink "$item" "$target_item"
            fi
        elif [[ -d "$target_item" ]]; then
            create_symlinks_from_dir "$item" "$target_item"
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

        local target_item="$target_dir/$name"

        _link_item "$item" "$target_item"
    done

    # Also handle hidden files (dotfiles within home/)
    for item in "$source_dir"/.*; do
        [[ -e "$item" ]] || continue
        local name
        name="$(basename "$item")"
        [[ "$name" == "." || "$name" == ".." ]] && continue
        should_exclude "$name" && continue

        local target_item="$target_dir/$name"
        _link_item "$item" "$target_item"
    done

    _LINK_DEPTH=$((_LINK_DEPTH - 1))
    if [[ $_LINK_DEPTH -eq 0 && $_SKIP_COUNT -gt 0 ]]; then
        info "$_SKIP_COUNT files already linked"
        _SKIP_COUNT=0
    fi
}

# --- JSON

# Deep-merge source JSON into target (source wins on conflicts).
# Creates target if it doesn't exist.
merge_json() {
    local source="$1"
    local target="$2"

    [[ -f "$source" ]] || { warning "merge_json: source not found: $source"; return 1; }

    if ! command -v jq &>/dev/null; then
        warning "merge_json: jq not found, copying source to target"
        cp "$source" "$target"
        return 0
    fi

    if [[ -f "$target" ]]; then
        jq -s '.[0] * .[1]' "$target" "$source" > "$target.tmp" && mv "$target.tmp" "$target"
    else
        cp "$source" "$target"
    fi
}
