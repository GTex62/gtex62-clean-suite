#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
GATE="$SCRIPT_DIR/pf-ssh-gate.sh"
if ! "$GATE" allow; then
  printf 'SSH PAUSED - AP\n'
  exit 0
fi

# --- Dependency note ---
# This script calls zyxel_cmd.sh. That helper can use sshpass (password file) or SSH keys.
# If you use sshpass on Debian/Ubuntu: sudo apt install sshpass

ZYXEL_CMD="$SCRIPT_DIR/zyxel_cmd.sh"

run_zyxel() {
  local ip="$1"
  shift
  local out rc
  set +e
  out="$("$ZYXEL_CMD" "$ip" "$@")"
  rc=$?
  set -e
  if [ "$rc" -ne 0 ] || [ -z "$out" ]; then
    "$GATE" trip "AP_SSH_FAIL"
    exit 0
  fi
  if [ "$rc" -eq 0 ]; then
    "$GATE" reset
    printf '%s' "$out"
    return 0
  fi
  return 1
}

# Override by exporting AP_IPS or using start-conky.sh
AP_IPS_CSV="${AP_IPS:-192.168.40.4,192.168.40.5,192.168.40.6}"
AP_LABELS_CSV="${AP_LABELS:-AP1,AP2,AP3}"
IFS="," read -r -a AP_IPS <<< "$AP_IPS_CSV"
IFS="," read -r -a AP_LBL <<< "$AP_LABELS_CSV"

for idx in "${!AP_IPS[@]}"; do
  ip="${AP_IPS[$idx]}"
  label="${AP_LBL[$idx]:-AP$((idx+1))}"

  if ! out_ver="$(run_zyxel "$ip" "show version")"; then
    exit 0
  fi
  out_ver="${out_ver//$'\r'/}"
  model="$(awk -F':' '/^model[[:space:]]*:/{gsub(/^[[:space:]]+|[[:space:]]+$/,"",$2); print $2; exit}' <<<"$out_ver")"

  if ! out_cpu="$(run_zyxel "$ip" "show cpu status")"; then
    exit 0
  fi
  out_cpu="${out_cpu//$'\r'/}"
  cpu="$(awk -F':' '/^CPU utilization:/{gsub(/^[[:space:]]+|[[:space:]]+$/,"",$2); print $2; exit}' <<<"$out_cpu")"

  # Count lines that begin with two spaces then MAC:
  # (works with the "show wireless-hal station info" output you pasted)
  if ! out_sta="$(run_zyxel "$ip" "show wireless-hal station info")"; then
    exit 0
  fi
  out_sta="${out_sta//$'\r'/}"
  clients="$(grep -cE '^[[:space:]]{2}MAC:' <<<"$out_sta" || true)"

  printf "%-10s (%s) - CPU: %s | Clients: %s\n" "$label" "${model:-N/A}" "${cpu:-N/A}" "${clients:-0}"
done
