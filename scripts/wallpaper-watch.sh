#!/usr/bin/env bash

set -u

if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <wallpaper> [monitor]" >&2
    exit 1
fi

if ! command -v dms >/dev/null 2>&1; then
    echo "dms is not installed or not in PATH." >&2
    exit 127
fi

wallpaper="$1"
monitor="${2:-All}"

run_with_retry() {
    local attempts="$1"
    shift

    local try
    for ((try = 1; try <= attempts; try++)); do
        if "$@"; then
            return 0
        fi
        sleep 0.2
    done
    return 1
}

# Keep DMS wallpaper state synced with waypaper selection.
if [ -n "$monitor" ] && [ "$monitor" != "All" ]; then
    if ! run_with_retry 3 dms ipc call wallpaper setFor "$monitor" "$wallpaper" >/dev/null 2>&1; then
        echo "Warning: failed to sync DMS wallpaper state for monitor '$monitor'." >&2
    fi
else
    if ! run_with_retry 3 dms ipc call wallpaper set "$wallpaper" >/dev/null 2>&1; then
        echo "Warning: failed to sync DMS wallpaper state in global mode." >&2
    fi
fi

# Always trigger matugen refresh, even if IPC sync failed.
if ! run_with_retry 3 dms matugen queue --kind image --value "$wallpaper" >/dev/null 2>&1; then
    echo "Warning: failed to refresh DMS matugen palette." >&2
    exit 1
fi

