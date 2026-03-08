#!/usr/bin/env bash

set -u

if hyprctl clients 2>/dev/null | grep -q "class: SPlayer"; then
    hyprctl dispatch focuswindow "class:SPlayer" >/dev/null 2>&1
    exit 0
fi

exec /opt/SPlayer/SPlayer
