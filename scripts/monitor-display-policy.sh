#!/usr/bin/env bash

set -euo pipefail

INTERNAL_MONITOR="${INTERNAL_MONITOR:-eDP-1}"

log() {
    echo "[monitor-display-policy] $*" >&2
}

require_cmd() {
    local cmd="$1"
    if ! command -v "$cmd" >/dev/null 2>&1; then
        log "Missing required command: $cmd"
        exit 1
    fi
}

wait_for_hyprctl() {
    local tries=20
    local delay=0.2
    local i=0
    while [ "$i" -lt "$tries" ]; do
        if hyprctl -j monitors >/dev/null 2>&1; then
            return 0
        fi
        i=$((i + 1))
        sleep "$delay"
    done
    log "Hyprland IPC is not ready."
    return 1
}

get_active_monitors_json() {
    hyprctl -j monitors 2>/dev/null || echo "[]"
}

pick_external_monitor() {
    get_active_monitors_json \
        | jq -r --arg internal "$INTERNAL_MONITOR" '
            [.[] | select(.name != $internal) | .name] | .[0] // ""
        '
}

list_workspace_names() {
    hyprctl -j workspaces 2>/dev/null \
        | jq -r '
            [ .[] | (.name // (.id | tostring)) | select(length > 0) ]
            | unique
            | .[]
        '
}

move_all_workspaces_to_monitor() {
    local target_monitor="$1"
    local ws=""

    while IFS= read -r ws; do
        [ -n "$ws" ] || continue
        hyprctl dispatch moveworkspacetomonitor "$ws" "$target_monitor" >/dev/null 2>&1 || true
    done < <(list_workspace_names)
}

lid_close() {
    local external_monitor=""

    external_monitor="$(pick_external_monitor)"
    if [ -z "$external_monitor" ]; then
        log "No active external monitor found; skip lid-close actions."
        return 0
    fi

    move_all_workspaces_to_monitor "$external_monitor"

    if ! hyprctl dispatch dpms off "$INTERNAL_MONITOR" >/dev/null 2>&1; then
        hyprctl keyword monitor "$INTERNAL_MONITOR,disable" >/dev/null 2>&1 || true
    fi

    log "Moved workspaces to '$external_monitor' and turned off '$INTERNAL_MONITOR'."
}

lid_open() {
    if ! hyprctl dispatch dpms on "$INTERNAL_MONITOR" >/dev/null 2>&1; then
        hyprctl keyword monitor "$INTERNAL_MONITOR,preferred,auto,auto" >/dev/null 2>&1 || true
    fi

    sleep 0.3
    move_all_workspaces_to_monitor "$INTERNAL_MONITOR"

    log "Turned on '$INTERNAL_MONITOR' and moved workspaces back."
}

max_refresh() {
    local monitors_json=""
    local name=""
    local mode=""
    local pos=""
    local scale=""

    monitors_json="$(get_active_monitors_json)"

    while IFS=$'\t' read -r name mode pos scale; do
        [ -n "$name" ] || continue
        [ -n "$mode" ] || continue

        hyprctl keyword monitor "$name,$mode,$pos,$scale" >/dev/null 2>&1 || true
    done < <(
        jq -r '
            def parsed_modes:
                [
                    .availableModes[]?
                    | capture("^(?<w>[0-9]+)x(?<h>[0-9]+)@(?<hz>[0-9]+(?:\\.[0-9]+)?)")?
                    | select(. != null)
                    | { w: (.w | tonumber), h: (.h | tonumber), hz: (.hz | tonumber) }
                ];

            .[] as $m
            | (parsed_modes | if length == 0 then empty else sort_by(.w * .h, .w, .h, .hz) | last end) as $best
            | select($best != null)
            | "\($m.name)\t\($best.w)x\($best.h)@\($best.hz)\t\(($m.x // 0))x\(($m.y // 0))\t\(($m.scale // 1.0))"
        ' <<<"$monitors_json"
    )

    log "Applied highest refresh rate per monitor at highest available resolution."
}

main() {
    local action="${1:-}"

    require_cmd hyprctl
    require_cmd jq
    wait_for_hyprctl

    case "$action" in
        lid-close)
            lid_close
            ;;
        lid-open)
            lid_open
            ;;
        max-refresh)
            max_refresh
            ;;
        *)
            echo "Usage: $0 <lid-close|lid-open|max-refresh>" >&2
            exit 2
            ;;
    esac
}

main "${1:-}"
