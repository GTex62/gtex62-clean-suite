#!/usr/bin/env bash
# Shared environment for Conky widgets (exports only)

export CONKY_SUITE_DIR="${CONKY_SUITE_DIR:-$HOME/.config/conky/gtex62-clean-suite}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
# export XDG_CACHE_HOME="/dev/shm"  # RAM cache: uncomment and comment the line above
export CONKY_CACHE_DIR="${CONKY_CACHE_DIR:-$XDG_CACHE_HOME/conky}"
export PFSENSE_HOST="${PFSENSE_HOST:-192.168.40.1}"
export AP_IPS="${AP_IPS:-192.168.40.4,192.168.40.5,192.168.40.6}"
export AP_LABELS="${AP_LABELS:-Closet,Office,Great Room}"
