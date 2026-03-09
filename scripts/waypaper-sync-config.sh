#!/usr/bin/env bash

set -euo pipefail

config_file="${XDG_CONFIG_HOME:-$HOME/.config}/waypaper/config.ini"
watch_script="$HOME/.config/hypr/scripts/wallpaper-watch.sh"
post_command="$watch_script \$wallpaper \$monitor"

mkdir -p "$(dirname "$config_file")"

if [ ! -f "$config_file" ]; then
    printf "[Settings]\n" > "$config_file"
fi

set_settings_key() {
    local key="$1"
    local value="$2"
    local tmp_file

    tmp_file="$(mktemp)"

    awk -v key="$key" -v value="$value" '
        BEGIN {
            saw_settings = 0
            in_settings = 0
            key_set = 0
        }

        /^\[.*\]$/ {
            if (in_settings && !key_set) {
                printf "%s = %s\n", key, value
                key_set = 1
            }

            if ($0 == "[Settings]") {
                saw_settings = 1
                in_settings = 1
            } else {
                in_settings = 0
            }

            print
            next
        }

        {
            if (in_settings && $0 ~ "^[[:space:]]*" key "[[:space:]]*=") {
                printf "%s = %s\n", key, value
                key_set = 1
                next
            }

            print
        }

        END {
            if (!saw_settings) {
                print "[Settings]"
                printf "%s = %s\n", key, value
            } else if (in_settings && !key_set) {
                printf "%s = %s\n", key, value
            }
        }
    ' "$config_file" > "$tmp_file"

    mv "$tmp_file" "$config_file"
}

set_settings_key "backend" "swww"
set_settings_key "post_command" "$post_command"

