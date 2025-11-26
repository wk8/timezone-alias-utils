#!/bin/sh

# creates symlinks for timezone aliases based on groups of equivalent TZs.
# data goes into a here-doc at the bottom, populated by the Dockerfile.
#
# Each non-empty, non-comment line:
#   TZ1 TZ2 TZ3 ...
# meaning TZ1, TZ2, TZ3 are equivalent.
#
# Additionally, takes extra override files as optional arguments, where each
# override file contains extra aliases, one per line, e.g.
# TZ1 TZ2
# means that TZ1 should be symlinked to TZ2

(set -u) >/dev/null 2>&1 && set -u
set -e

ZONEINFO_DIR=${ZONEINFO_DIR:-/usr/share/zoneinfo}

# sanity check
if [ ! -d "$ZONEINFO_DIR" ]; then
    echo "Zoneinfo directory '$ZONEINFO_DIR' does not exist" >&2
    exit 1
fi

# returns 0 if PATH exists as file, dir, or symlink
exists() {
    path=$1
    if [ -L "$path" ] || [ -f "$path" ] || [ -d "$path" ]; then
        return 0
    fi
    return 1
}

# ensure_link LINK_TZ TARGET_TZ CONTEXT
# symlinks LINK_TZ to TARGET_TZ under $ZONEINFO_DIR.
# CONTEXT is just for logging ("group", "file <name>", etc.).
ensure_link() {
    link_tz=$1
    target_tz=$2
    context=$3

    target_path="$ZONEINFO_DIR/$target_tz"
    dest="$ZONEINFO_DIR/$link_tz"

    if ! exists "$target_path"; then
        echo "Target zone file does not exist for mapping '$link_tz $target_tz' ($context), missing '$target_path'" >&2
        return 0
    fi

    # if destination already exists, leave it alone
    if exists "$dest"; then
        return 0
    fi

    # ensure parent directory exists
    dir=${dest%/*}
    if [ ! -d "$dir" ]; then
        if ! mkdir -p "$dir"; then
            echo "Failed to create directory '$dir' for '$link_tz' ($context)" >&2
            exit 1
        fi
    fi

    if ln -s "$target_path" "$dest"; then
        echo "Created symlink ($context): $link_tz -> $target_tz"
    else
        echo "Failed to create symlink ($context): $link_tz -> $target_tz" >&2
        exit 1
    fi
}

if [ "$#" -gt 0 ]; then
    for ALIASES_FILE in "$@"; do
        if [ ! -r "$ALIASES_FILE" ]; then
            echo "Aliases file '$ALIASES_FILE' not readable" >&2
            exit 1
        fi

        while IFS= read -r line || [ -n "$line" ]; do
            case $line in
                ''|'#'*) continue ;;
            esac

            # expect: TZ1 TZ2
            set -- $line
            tz_link=$1
            tz_target=$2

            if [ -z "$tz_link" ] || [ -z "$tz_target" ]; then
                echo "Invalid line in '$ALIASES_FILE': $line" >&2
                exit 1
            fi

            ensure_link "$tz_link" "$tz_target" "file $ALIASES_FILE"
        done < "$ALIASES_FILE"
    done
fi

while IFS= read -r line || [ -n "$line" ]; do
    case $line in
        ''|'#'*) continue ;;
    esac

    # find a canonical target that already exists
    target_tz=
    target_path=

    for tz in $line; do
        candidate="$ZONEINFO_DIR/$tz"
        if exists "$candidate"; then
            target_tz=$tz
            target_path=$candidate
            break
        fi
    done

    # if none exist, warn and skip this group
    if [ -z "$target_tz" ]; then
        echo "No existing zone file in group: $line" >&2
        continue
    fi

    # now ensure all others in the group link to target_tz
    for tz in $line; do
        ensure_link "$tz" "$target_tz" "group"
    done

done << 'EOF'
# alias groups below, one group per line, space-separated.
# Examples:
# America/Los_Angeles US/Pacific PST8PDT
# UTC Etc/UTC Zulu
# Europe/Berlin Europe/Zurich CET
# then at the end
# EOF
