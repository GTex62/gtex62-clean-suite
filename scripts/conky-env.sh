#!/usr/bin/env bash
# Shared environment for Conky widgets (exports only)

export PFSENSE_HOST="${PFSENSE_HOST:-192.168.40.1}"
export AP_IPS="${AP_IPS:-192.168.40.4,192.168.40.5,192.168.40.6}"
export AP_LABELS="${AP_LABELS:-Closet,Office,Great Room}"
