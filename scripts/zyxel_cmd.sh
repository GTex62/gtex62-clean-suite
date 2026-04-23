#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
GATE="$SCRIPT_DIR/pf-ssh-gate.sh"
if [[ $# -lt 2 ]]; then
  echo "Usage: zyxel_cmd.sh <ip> <command...>" >&2
  exit 2
fi
IP="$1"; shift
CMD="$*"

PASSFILE="$HOME/.config/zyxel_ap/.pass"
if [[ ! -s "$PASSFILE" ]]; then
  echo "Password file not found: $PASSFILE" >&2
  exit 3
fi

should_trip_gate() {
  local msg="${1-}"
  [[ "$msg" =~ [Pp]ermission\ denied ]] && return 0
  [[ "$msg" =~ [Aa]uthentication\ failed ]] && return 0
  [[ "$msg" =~ [Aa]ccess\ denied ]] && return 0
  [[ "$msg" =~ [Tt]oo\ many\ authentication\ failures ]] && return 0
  [[ "$msg" =~ [Hh]ost\ key\ verification\ failed ]] && return 0
  return 1
}

if ! "$GATE" allow; then
  exit 0
fi

stderr_file="$(mktemp)"
trap 'rm -f "$stderr_file"' EXIT

if sshpass -f "$PASSFILE" ssh -o ConnectTimeout=5 -o ConnectionAttempts=1 -o ServerAliveInterval=5 -o ServerAliveCountMax=1 -o LogLevel=ERROR -o PubkeyAuthentication=no -o KbdInteractiveAuthentication=yes -o PreferredAuthentications=keyboard-interactive,password -o NumberOfPasswordPrompts=1 -o StrictHostKeyChecking=accept-new -tt admin@"$IP" 2>"$stderr_file" <<EOC
$CMD
exit
EOC
then
  "$GATE" reset
else
  err="$(tr -d '\r' < "$stderr_file")"
  if should_trip_gate "$err"; then
    "$GATE" trip "AP_SSH_FAIL"
  fi
  [[ -n "$err" ]] && printf '%s\n' "$err" >&2
  exit 1
fi
