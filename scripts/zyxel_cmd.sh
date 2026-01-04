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

if ! "$GATE" allow; then
  exit 0
fi

if sshpass -f "$PASSFILE" ssh -o ConnectTimeout=5 -o ConnectionAttempts=1 -o ServerAliveInterval=5 -o ServerAliveCountMax=1 -o LogLevel=ERROR -o PubkeyAuthentication=no -o PreferredAuthentications=password -o NumberOfPasswordPrompts=1 -o StrictHostKeyChecking=accept-new -tt admin@"$IP" <<EOC
$CMD
exit
EOC
then
  "$GATE" reset
else
  "$GATE" trip "AP_SSH_FAIL"
  exit 0
fi
