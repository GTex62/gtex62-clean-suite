#!/usr/bin/env bash
set -euo pipefail
XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
CACHE_DIR="${CONKY_CACHE_DIR:-$XDG_CACHE_HOME/conky}"
J="${1:-$CACHE_DIR/owm_forecast.json}"
jq -r '
  .list
  | group_by(.dt | strftime("%Y-%m-%d"))
  | .[:6]                                           # TODAY + next 5
  | to_entries
  | .[]
  | (
      .key as $i
      | .value as $d
      | {
          idx: $i,
          dt:  ($d[0].dt),
          hi:  ( [ $d[] | (.main.temp_max // .main.temp // 0) ] | max | floor ),
          lo:  ( [ $d[] | (.main.temp_min // .main.temp // 0) ] | min | floor ),
          icon: (
            ( [ $d[] | {icon:.weather[0].icon, hour:(.dt | strftime("%H") | tonumber)} ] ) as $arr
            | ( [ $arr[] | select(.hour >= 10 and .hour <= 16) | .icon ] ) as $day
            | ( if ($day|length) > 0
                then ($day | group_by(.) | max_by(length)[0])
                else ($arr[0].icon)
              end )
            | sub("n$";"d")
          )
        }
    )
  | "\(.idx)\t\(.dt)\t\(.hi)\t\(.lo)\t\(.icon)"
' "$J"
