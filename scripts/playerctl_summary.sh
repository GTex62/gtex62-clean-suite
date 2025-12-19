#!/usr/bin/env bash
# Prints a single JSON line with status, artist, title, album, length_us, position_s, art_url
# Uses the default (currently active) MPRIS player.

# Grab metadata in one go
meta=$(playerctl metadata --format '{{xesam:artist}}|{{xesam:title}}|{{xesam:album}}|{{mpris:length}}|{{mpris:artUrl}}' 2>/dev/null)
status=$(playerctl status 2>/dev/null)
position=$(playerctl position 2>/dev/null)

# If no player is active, output a minimal JSON
if [[ -z "$meta$status$position" ]]; then
  echo '{"status":"Stopped","artist":"","title":"","album":"","length_us":0,"position_s":0,"art_url":""}'
  exit 0
fi

IFS='|' read -r artist title album length_us art_url <<<"$meta"

# Normalize fields (avoid nulls)
artist=${artist:-}
title=${title:-}
album=${album:-}
length_us=${length_us:-0}
position=${position:-0}
art_url=${art_url:-}

# Emit JSON
printf '{"status":%q,"artist":%q,"title":%q,"album":%q,"length_us":%q,"position_s":%q,"art_url":%q}\n' \
  "$status" "$artist" "$title" "$album" "$length_us" "$position" "$art_url"
