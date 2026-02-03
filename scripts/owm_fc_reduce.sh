#!/usr/bin/env bash
set -euo pipefail

XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
CACHE_DIR="${CONKY_CACHE_DIR:-$XDG_CACHE_HOME/conky}"
ICON_DIR="$CACHE_DIR/icons"
FC_JSON="$CACHE_DIR/owm_forecast.json"
OUT_VARS="$CACHE_DIR/owm_days.vars"
LOG_FILE="$CACHE_DIR/owm_fetch.log"

mkdir -p "$CACHE_DIR" "$ICON_DIR"
[[ -s "$FC_JSON" ]] || exit 0

# Use jq localtime+strftime instead of strflocaltime (for broader jq compatibility)
jq -r '
  .city.timezone as $tz
  | .list
  | map(. + {
      local_dt: (.dt + $tz),
      day:      ((.dt + $tz) | localtime | strftime("%Y-%m-%d")),
      hour:     ((.dt + $tz) | localtime | strftime("%H") | tonumber)
    })
  | group_by(.day)
  | map({
      day:  .[0].day,
      name: (.[0].local_dt | localtime | strftime("%a")),
      hi:   (max_by(.main.temp).main.temp),
      lo:   (min_by(.main.temp).main.temp),
      icon: (
        ( [ .[] | {icon:.weather[0].icon, hour:(.dt + $tz | localtime | strftime("%H") | tonumber)} ] ) as $arr
        | ( [ $arr[] | select(.hour >= 10 and .hour <= 16) | .icon ] ) as $day
        | ( if ($day|length) > 0
            then ($day | group_by(.) | max_by(length)[0])
            else ($arr[0].icon)
          end )
        | sub("n$";"d")
      )
    })
  | .[:6]
  | to_entries[]
  | "D\(.key)_NAME=\(.value.name)\nD\(.key)_HI=\(.value.hi|tostring)\nD\(.key)_LO=\(.value.lo|tostring)\nD\(.key)_ICON=\(.value.icon)"
' "$FC_JSON" > "$OUT_VARS".tmp 2>>"$LOG_FILE" || {
  echo "$(date -Is) WARN: jq reduce failed" >> "$LOG_FILE"
  exit 0
}

mv -f "$OUT_VARS".tmp "$OUT_VARS"

# Cache icons to static filenames (fc0..fc5)
for i in 0 1 2 3 4 5; do
  code="$(grep -E "^D${i}_ICON=" "$OUT_VARS" | cut -d= -f2-)"
  [[ -n "$code" ]] || continue
  dst="$ICON_DIR/fc${i}.png"
  if [[ ! -f "$dst" ]]; then
    url="https://openweathermap.org/img/wn/${code}@2x.png"
    curl -fsS --max-time 6 -o "$dst" "$url" 2>>"$LOG_FILE" || true
  fi
done

exit 0
