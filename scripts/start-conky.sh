#!/usr/bin/env bash
# ${CONKY_SUITE_DIR:-~/.config/conky/gtex62-clean-suite}/scripts/start-conky.sh

export PFSENSE_HOST="${PFSENSE_HOST:-192.168.40.1}"
export AP_IPS="${AP_IPS:-192.168.40.4,192.168.40.5,192.168.40.6}" # Override via AP_IPS env if needed
export AP_LABELS="${AP_LABELS:-Closet,Office,Great Room}" # Order must match AP_IPS


pkill -x conky 2>/dev/null || true

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEFAULT_SUITE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
export CONKY_SUITE_DIR="${CONKY_SUITE_DIR:-$DEFAULT_SUITE_DIR}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export CONKY_CACHE_DIR="${CONKY_CACHE_DIR:-$XDG_CACHE_HOME/conky}"

SUITE_DIR="$CONKY_SUITE_DIR"
CACHE_DIR="$CONKY_CACHE_DIR"
mkdir -p "$CACHE_DIR"

SUITE_NAME="$(basename "$SUITE_DIR")"
WALLPAPER_DIR="$SUITE_DIR/wallpapers"
CACHE_LAST="$CACHE_DIR/${SUITE_NAME}-wallpaper"

mapfile -t WALLS < <(find "$WALLPAPER_DIR" -maxdepth 1 -type f -printf '%f\n' | sort)

if [ "${#WALLS[@]}" -eq 0 ]; then
  echo "No wallpapers found in: $WALLPAPER_DIR"
  exit 1
fi

DEFAULT_CHOICE=""
if [ -f "$CACHE_LAST" ]; then
  last="$(cat "$CACHE_LAST" 2>/dev/null || true)"
  for i in "${!WALLS[@]}"; do
    if [ "${WALLS[$i]}" = "$last" ]; then
      DEFAULT_CHOICE="$((i+1))"
      break
    fi
  done
fi

if [ "${#WALLS[@]}" -eq 1 ]; then
  choice="1"
else
  echo "Available wallpapers for $SUITE_NAME:"
  for i in "${!WALLS[@]}"; do
    printf "%d) %s\n" "$((i+1))" "${WALLS[$i]}"
  done
  if [ -n "$DEFAULT_CHOICE" ]; then
    read -rp "Select wallpaper [1-${#WALLS[@]}] (Enter=$DEFAULT_CHOICE): " choice
    choice="${choice:-$DEFAULT_CHOICE}"
  else
    read -rp "Select wallpaper [1-${#WALLS[@]}]: " choice
  fi
fi

if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#WALLS[@]} )); then
  echo "Invalid selection."
  exit 1
fi

WALLPAPER_FILE="${WALLS[$((choice-1))]}"
echo "$WALLPAPER_FILE" > "$CACHE_LAST"

WALLPAPER_PATH="$WALLPAPER_DIR/$WALLPAPER_FILE"
feh --no-xinerama --bg-fill "$WALLPAPER_PATH"



# Adjust gap_x for your monitor layout
# Example assumes Monitor #2 is on the right of primary display

# System info - left edge of 2nd monitor
conky -c "$SUITE_DIR/widgets/sys-info.conky.conf" &

# Network info below system info
conky -c "$SUITE_DIR/widgets/net-sys.conky.conf" &

# Weather center below date & time
conky -c "$SUITE_DIR/widgets/weather.conky.conf" &

# Date & time above weather
conky -c "$SUITE_DIR/widgets/date-time.conky.conf" &

# Calendar on top right
conky -c "$SUITE_DIR/widgets/calendar.conky.conf" &

#Notes on right edge
conky -c "$SUITE_DIR/widgets/notes.conky.conf" &

# Music widget center below weather
conky -c "$SUITE_DIR/widgets/music.conky.conf" &

# pfSense widget center bottom
conky -c "$SUITE_DIR/widgets/pfsense.conky.conf" &

# AP WBE530 widget next to Network info widget
#conky -c "$SUITE_DIR/widgets/ap-wbe530.conky.conf" &

# Lyrics widget
conky -c "$SUITE_DIR/widgets/music-lyrics.conky.conf" &
