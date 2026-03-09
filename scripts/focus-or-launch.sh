#!/usr/bin/env bash

set -u

target="${1:-}"

if [ -z "$target" ]; then
    echo "Usage: $0 <qq|obsidian|browser|telegram|clash>" >&2
    exit 2
fi

has_window() {
    local grep_pattern="$1"
    hyprctl clients 2>/dev/null | grep -Eq "$grep_pattern"
}

focus_window() {
    local class_regex="$1"
    hyprctl dispatch focuswindow "class:${class_regex}" >/dev/null 2>&1
}

case "$target" in
    qq)
         if has_window 'class: (QQ|qq|linuxqq)'; then
            focus_window '^(QQ|qq|linuxqq)$'
            exit 0
        fi
        if pgrep -x linuxqq >/dev/null 2>&1 || pgrep -x qq >/dev/null 2>&1 || pgrep -f '/opt/QQ/qq' >/dev/null 2>&1; then
            exit 0
        fi
        exec linuxqq
        ;;
    obsidian)
        if has_window 'class: (obsidian|Obsidian)'; then
            focus_window '^(obsidian|Obsidian)$'
            exit 0
        fi
        if pgrep -x obsidian >/dev/null 2>&1; then
            exit 0
        fi
        exec obsidian
        ;;
    browser)
        if has_window 'class: ([Zz]en(|-.*)|zen-browser)'; then
            focus_window '^([Zz]en(|-.*)|zen-browser)$'
            exit 0
        fi
        if pgrep -x zen-browser >/dev/null 2>&1 || pgrep -x zen >/dev/null 2>&1 || pgrep -f '/zen-browser' >/dev/null 2>&1; then
            exit 0
        fi
        exec zen-browser
        ;;
    telegram)
        if has_window 'class: (org\.telegram\.desktop|TelegramDesktop|telegram-desktop)'; then
            focus_window '^(org\.telegram\.desktop|TelegramDesktop|telegram-desktop)$'
            exit 0
        fi
        if pgrep -x telegram-desktop >/dev/null 2>&1 || pgrep -x Telegram >/dev/null 2>&1; then
            exit 0
        fi
        exec telegram-desktop
        ;;
    clash)
        if has_window 'class: (clash-verge|io\.github\.clash-verge-rev\.clash-verge-rev)'; then
            focus_window '^(clash-verge|io\.github\.clash-verge-rev\.clash-verge-rev)$'
            exit 0
        fi
        # Clash Verge is single-instance; launching again usually asks the running instance to show window.
        exec clash-verge
        ;;
    *)
        echo "Unknown target: ${target}" >&2
        echo "Usage: $0 <qq|obsidian|browser|telegram|clash>" >&2
        exit 2
        ;;
esac
