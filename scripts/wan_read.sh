#!/usr/bin/env bash
XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
CACHE_DIR="${CONKY_CACHE_DIR:-$XDG_CACHE_HOME/conky}"
f="$CACHE_DIR/scripts/wan_ip"
v="$(tr -d '\r\n' < "$f" 2>/dev/null)"
[ -n "$v" ] && printf '%s\n' "$v" || printf '(resolving…)\n'
