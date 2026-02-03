#!/usr/bin/env bash
set -euo pipefail
SUITE_DIR="${CONKY_SUITE_DIR:-$HOME/.config/conky/gtex62-clean-suite}"
XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
CACHE_DIR="${CONKY_CACHE_DIR:-$XDG_CACHE_HOME/conky}"
DAILY="${1:-$CACHE_DIR/owm_forecast.json}"
THEME_DIR="${2:-$SUITE_DIR/icons/owm}"
OUTDIR="$CACHE_DIR/icons"
mkdir -p "$OUTDIR" "$THEME_DIR"

ensure_code_png() {
  local code="$1" dst="$THEME_DIR/${code}.png"
  [[ -s "$dst" ]] && return 0
  curl -fsSL "https://openweathermap.org/img/wn/${code}@2x.png" -o "$dst" || return 1
}

codes="$(jq -r '
  .list
  | group_by(.dt | strftime("%Y-%m-%d"))
  | .[:6]
  | map(
      ( [ .[] | {icon:.weather[0].icon, hour:(.dt | strftime("%H") | tonumber)} ] ) as $arr
      | ( [ $arr[] | select(.hour >= 10 and .hour <= 16) | .icon ] ) as $day
      | ( if ($day|length) > 0
          then ($day | group_by(.) | max_by(length)[0])
          else ($arr[0].icon)
        end )
      | sub("n$";"d")
    )
  | .[]
' "$DAILY" 2>/dev/null || true)"

i=0
while read -r code; do
  [[ -z "$code" ]] && continue
  ensure_code_png "$code" || true
  src="$THEME_DIR/${code}.png"
  dest="$OUTDIR/fc${i}.png"
  [[ -s "$src" ]] && cp -f "$src" "$dest"
  i=$((i+1))
  [[ $i -ge 6 ]] && break
done <<< "$codes"

# --- Daylight override for fc0: if it's daytime, mirror the current icon ---
CUR_JSON="$CACHE_DIR/owm_current.json"
ICON_DIR="$CACHE_DIR/icons"

if [ -f "$CUR_JSON" ]; then
  now=$(date +%s)
  sr=$(jq -r '.sys.sunrise // 0' "$CUR_JSON" 2>/dev/null)
  ss=$(jq -r '.sys.sunset  // 0' "$CUR_JSON" 2>/dev/null)
  # Only override in daylight and if we have a current.png
  if [ "$now" -ge "$sr" ] && [ "$now" -le "$ss" ] && [ -f "$ICON_DIR/current.png" ]; then
    cp -f "$ICON_DIR/current.png" "$ICON_DIR/fc0.png"
  fi
fi
