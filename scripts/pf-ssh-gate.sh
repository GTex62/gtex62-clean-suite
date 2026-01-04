#!/usr/bin/env bash
set -euo pipefail

state_dir="${HOME}/.cache/conky/pfsense"
lock_file="${state_dir}/ssh.lock"
state_file="${state_dir}/ssh_state"

mkdir -p "$state_dir"

now_ts() {
  date +%s
}

sanitize_reason() {
  local r="${1-}"
  r=${r//|/}
  r=$(printf '%s' "$r" | tr '[:space:]' '_')
  printf '%s' "$r"
}

load_state() {
  tripped=0
  fails=0
  reason=""
  until=0
  last_fail_ts=0
  last_ok_ts=0

  if [[ -f "$state_file" ]]; then
    while IFS='=' read -r key value; do
      case "$key" in
        tripped) tripped=${value:-0} ;;
        fails) fails=${value:-0} ;;
        reason) reason=${value-} ;;
        until) until=${value:-0} ;;
        last_fail_ts) last_fail_ts=${value:-0} ;;
        last_ok_ts) last_ok_ts=${value:-0} ;;
      esac
    done < "$state_file"
  fi
}

write_state() {
  local tmp
  tmp=$(mktemp "${state_dir}/ssh_state.tmp.XXXXXX")
  {
    printf 'tripped=%s\n' "$tripped"
    printf 'fails=%s\n' "$fails"
    printf 'reason=%s\n' "$reason"
    printf 'until=%s\n' "$until"
    printf 'last_fail_ts=%s\n' "$last_fail_ts"
    printf 'last_ok_ts=%s\n' "$last_ok_ts"
  } > "$tmp"
  mv "$tmp" "$state_file"
}

cooldown_for_fails() {
  case "$1" in
    1) printf '3' ;;
    2) printf '10' ;;
    3) printf '30' ;;
    4) printf '120' ;;
    *) printf '600' ;;
  esac
}

usage() {
  printf 'Usage: %s {allow|trip <reason> [cooldown_seconds]|reset|status}\n' "${0##*/}" >&2
}

if [[ $# -lt 1 ]]; then
  usage
  exit 2
fi

exec {lock_fd}>"$lock_file"
flock -x "$lock_fd"

load_state

cmd="$1"
shift

case "$cmd" in
  allow)
    now=$(now_ts)
    if [[ "$tripped" -eq 1 && "$now" -lt "$until" ]]; then
      exit 1
    fi
    exit 0
    ;;
  trip)
    if [[ $# -lt 1 ]]; then
      usage
      exit 2
    fi
    now=$(now_ts)
    fails=$((fails + 1))
    tripped=1
    reason=$(sanitize_reason "$1")
    if [[ $# -ge 2 ]]; then
      cooldown="$2"
    else
      cooldown=$(cooldown_for_fails "$fails")
    fi
    until=$((now + cooldown))
    last_fail_ts=$now
    write_state
    ;;
  reset)
    now=$(now_ts)
    tripped=0
    fails=0
    reason=""
    until=0
    last_ok_ts=$now
    write_state
    ;;
  status)
    now=$(now_ts)
    if [[ "$tripped" -eq 1 && "$now" -lt "$until" ]]; then
      left=$((until - now))
      printf 'TRIPPED|left=%s|fails=%s|reason=%s\n' "$left" "$fails" "$reason"
    else
      printf 'OK\n'
    fi
    ;;
  *)
    usage
    exit 2
    ;;
esac
