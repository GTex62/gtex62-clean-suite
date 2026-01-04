#!/usr/bin/env bash
set -euo pipefail

AP_IPS_CSV="${AP_IPS:-192.168.1.2,192.168.1.3,192.168.1.4}"
IFS="," read -r -a AP_IPS <<< "$AP_IPS_CSV"
AP_LBL=( "Closet"       "Office"       "Great Room" )

for idx in "${!AP_IPS[@]}"; do
  ip="${AP_IPS[$idx]}"
  label="${AP_LBL[$idx]}"

  out="$(
    ~/.config/conky/gtex62-clean-suite/scripts/zyxel_cmd.sh "$ip" $'show version\nshow cpu status\nexit' \
      | tr -d '\r'
  )"

  model="$(awk -F':' '/^model[[:space:]]*:/{gsub(/^[[:space:]]+|[[:space:]]+$/,"",$2); print $2; exit}' <<<"$out")"
  cpu="$(awk   -F':' '/^CPU utilization:/{gsub(/^[[:space:]]+|[[:space:]]+$/,"",$2); print $2; exit}' <<<"$out")"

  printf "%-10s (%s) - CPU: %s\n" "$label" "${model:-N/A}" "${cpu:-N/A}"
done
