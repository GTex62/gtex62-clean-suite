#!/usr/bin/env bash
set -euo pipefail

# Usage: metar.sh [STATION]
# STATION: ICAO (e.g., KMEM). If omitted, uses $STATION env or KMEM.

STATION="$(echo "${1:-${STATION:-KMEM}}" | tr '[:lower:]' '[:upper:]')"
XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
CACHE_DIR="${CONKY_CACHE_DIR:-$XDG_CACHE_HOME/conky}"
mkdir -p "$CACHE_DIR"
CACHE="$CACHE_DIR/metar_${STATION}_raw.txt"   # cache file (decoded feed)
AGE_LIMIT=600                            # seconds (10 min)
URL="https://tgftp.nws.noaa.gov/data/observations/metar/decoded/${STATION}.TXT"

# If cache is fresh, use it
if [ -f "$CACHE" ] && [ $(( $(date +%s) - $(stat -c %Y "$CACHE") )) -lt "$AGE_LIMIT" ]; then
  cat "$CACHE"
  exit 0
fi

# Fetch decoded METAR text (contains the 'ob:' line we strip later)
if raw="$(curl -fsS "$URL" 2>/dev/null)"; then
  printf "%s\n" "$raw" > "$CACHE"
  cat "$CACHE"
  exit 0
fi

# Fallback to stale cache if fetch failed
[ -f "$CACHE" ] && cat "$CACHE" || exit 1

