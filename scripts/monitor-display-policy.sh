#!/usr/bin/env bash

set -euo pipefail

INTERNAL_MONITOR="${INTERNAL_MONITOR:-eDP-1}"
EXTERNAL_MONITOR="${EXTERNAL_MONITOR:-HDMI-A-1}"

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

get_monitors_json() {
    hyprctl -j monitors all 2>/dev/null || hyprctl -j monitors 2>/dev/null || echo "[]"
}

monitor_exists_in_hypr() {
    local monitor="$1"
    local monitors_json="$2"

    jq -e --arg monitor "$monitor" '[.[] | select(.name == $monitor)] | length > 0' \
        <<<"$monitors_json" >/dev/null
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

lid_is_closed() {
    local state_file=""
    local found_any=false

    for state_file in /proc/acpi/button/lid/*/state; do
        [ -f "$state_file" ] || continue
        found_any=true

        if grep -qi "closed" "$state_file"; then
            return 0
        fi
    done

    # 找不到 ACPI lid 状态时，默认按开盖处理，避免误关内屏
    if [ "$found_any" = false ]; then
        return 1
    fi

    return 1
}

hdmi_is_connected() {
    local status_file=""
    local found_status=false

    for status_file in /sys/class/drm/*-"$EXTERNAL_MONITOR"/status; do
        [ -f "$status_file" ] || continue
        found_status=true

        if grep -qi "connected" "$status_file"; then
            return 0
        fi
    done

    # 某些环境下 /sys/class/drm 不可用，回退到 hyprctl monitors 信息判断
    if [ "$found_status" = false ]; then
        local monitors_json=""
        monitors_json="$(get_monitors_json)"
        if monitor_exists_in_hypr "$EXTERNAL_MONITOR" "$monitors_json"; then
            return 0
        fi
    fi

    return 1
}

get_best_mode_for_monitor() {
    local monitor="$1"
    local monitors_json="$2"

    jq -r --arg monitor "$monitor" '
        def parse_mode:
            capture("^(?<w>[0-9]+)x(?<h>[0-9]+)@(?<hz>[0-9]+(?:\\.[0-9]+)?)(?:Hz)?.*$")?;

        [
            .[]
            | select(.name == $monitor)
            | .availableModes[]?
            | parse_mode
            | select(. != null)
            | {
                w: (.w | tonumber),
                h: (.h | tonumber),
                hz: (.hz | tonumber)
            }
        ]
        | if length == 0 then
              ""
          else
              sort_by(.w * .h, .w, .h, .hz)
              | last
              | "\(.w)x\(.h)@\(.hz)"
          end
    ' <<<"$monitors_json"
}

apply_monitor_mode() {
    local monitor="$1"
    local mode="$2"

    if [ -n "$mode" ]; then
        hyprctl keyword monitor "$monitor,$mode,auto,auto" >/dev/null 2>&1 || true
    else
        hyprctl keyword monitor "$monitor,preferred,auto,auto" >/dev/null 2>&1 || true
    fi
}

disable_monitor() {
    local monitor="$1"
    hyprctl keyword monitor "$monitor,disable" >/dev/null 2>&1 || true
}

apply_internal_only() {
    local monitors_json=""
    local internal_mode=""

    monitors_json="$(get_monitors_json)"
    internal_mode="$(get_best_mode_for_monitor "$INTERNAL_MONITOR" "$monitors_json")"

    apply_monitor_mode "$INTERNAL_MONITOR" "$internal_mode"
    disable_monitor "$EXTERNAL_MONITOR"

    log "Applied internal-only policy on '$INTERNAL_MONITOR'."
}

apply_external_only() {
    local monitors_json=""
    local external_mode=""

    monitors_json="$(get_monitors_json)"
    external_mode="$(get_best_mode_for_monitor "$EXTERNAL_MONITOR" "$monitors_json")"

    apply_monitor_mode "$EXTERNAL_MONITOR" "$external_mode"
    move_all_workspaces_to_monitor "$EXTERNAL_MONITOR"
    disable_monitor "$INTERNAL_MONITOR"

    log "Applied external-only policy on '$EXTERNAL_MONITOR'."
}

apply_hdmi_primary_mirror() {
    local monitors_json=""
    local external_mode=""

    monitors_json="$(get_monitors_json)"
    external_mode="$(get_best_mode_for_monitor "$EXTERNAL_MONITOR" "$monitors_json")"

    # 先确保外接屏按最高模式启用，再将内屏镜像到外接屏
    apply_monitor_mode "$EXTERNAL_MONITOR" "$external_mode"
    hyprctl keyword monitor "$INTERNAL_MONITOR,preferred,auto,auto,mirror,$EXTERNAL_MONITOR" >/dev/null 2>&1 || true

    log "Applied mirror policy: '$INTERNAL_MONITOR' mirrors '$EXTERNAL_MONITOR' (HDMI primary)."
}

apply_best_mode_for_effective_primary() {
    local monitors_json=""
    local target_monitor=""
    local target_mode=""

    monitors_json="$(get_monitors_json)"

    if hdmi_is_connected; then
        target_monitor="$EXTERNAL_MONITOR"
    else
        target_monitor="$INTERNAL_MONITOR"
    fi

    target_mode="$(get_best_mode_for_monitor "$target_monitor" "$monitors_json")"
    apply_monitor_mode "$target_monitor" "$target_mode"

    log "Applied highest mode on effective primary monitor '$target_monitor'."
}

sync_policy() {
    if hdmi_is_connected; then
        if lid_is_closed; then
            apply_external_only
        else
            apply_hdmi_primary_mirror
        fi
    else
        apply_internal_only
    fi
}

main() {
    local action="${1:-}"

    require_cmd hyprctl
    require_cmd jq
    wait_for_hyprctl

    case "$action" in
        sync)
            sync_policy
            ;;
        lid-close)
            sync_policy
            ;;
        lid-open)
            sync_policy
            ;;
        max-refresh)
            apply_best_mode_for_effective_primary
            ;;
        *)
            echo "Usage: $0 <sync|lid-close|lid-open|max-refresh>" >&2
            exit 2
            ;;
    esac
}

main "${1:-}"
