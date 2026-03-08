#!/usr/bin/env bash

set -u

has_qq_window() {
    hyprctl clients 2>/dev/null | grep -Eq 'class: (QQ|qq|linuxqq)'
}

focus_qq_window() {
    hyprctl dispatch focuswindow "class:^(QQ|qq|linuxqq)$" >/dev/null 2>&1
}

qq_running() {
    pgrep -x linuxqq >/dev/null 2>&1 || pgrep -x qq >/dev/null 2>&1 || pgrep -f "/opt/QQ/qq" >/dev/null 2>&1
}

# 1) 已有窗口：直接聚焦
if has_qq_window; then
    focus_qq_window
    exit 0
fi

# 2) 后台还在：不重复拉起登录窗口
if qq_running; then
    exit 0
fi

# 3) 未运行：正常启动
exec linuxqq
