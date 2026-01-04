#!/usr/bin/env bash
set -euo pipefail

SUITE="$HOME/.config/conky/gtex62-clean-suite"
CMD="$SUITE/scripts/zyxel_cmd.sh"
MAP="$SUITE/scripts/ap_ipmap.csv"

# Conky color tokens (printed literally; Conky will render them)
COLOR_RED='${color red}'
COLOR_RST='${color}'

# ---------- load IP -> Name map ----------
declare -A NAME
if [[ -f "$MAP" ]]; then
  while IFS=, read -r ip name; do
    [[ -z "${ip// }" || "${ip:0:1}" == "#" ]] && continue
    ip="${ip//[$'\t\r\n ']/}"
    name="${name#"${name%%[![:space:]]*}"}"; name="${name%"${name##*[![:space:]]}"}"
    [[ -n "$ip" && -n "$name" ]] && NAME["$ip"]="$name"
  done < "$MAP"
fi

# ---------- APs (fixed order) ----------
# Override by exporting AP_IPS or using start-conky.sh
AP_IPS_CSV="${AP_IPS:-192.168.40.4,192.168.40.5,192.168.40.6}"
IFS="," read -r -a AP_IPS <<< "$AP_IPS_CSV"
AP_LBL=( "Closet"       "Office"       "Great Room" )

# Wrap with distinct first/next prefixes
wrap_list2() {
  local first_pref="$1" next_pref="$2" width="$3"; shift 3
  local IFS=", "
  local items=( "$@" )
  local line="$first_pref"
  local used_first=0
  local sep=""
  for it in "${items[@]}"; do
    local piece="${sep}${it}"
    if (( ${#line} + ${#piece} > width )); then
      printf "%s\n" "$line"
      line="$next_pref$it"
      sep=", "
    else
      line+="$piece"
      sep=", "
    fi
    used_first=1
  done
  printf "%s\n" "$line"
}

extract_ips() {
  grep -oE 'IPv4:[[:space:]]+[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | awk '{print $2}' | sort -u
}

for idx in "${!AP_IPS[@]}"; do
  ip="${AP_IPS[$idx]}"
  label="${AP_LBL[$idx]}"

  out="$("$CMD" "$ip" $'show wireless-hal station info\nexit' 2>/dev/null || true)"
  if [[ -z "$out" ]]; then
    printf "%s — %sDOWN%s\n\n" "$label" "$COLOR_RED" "$COLOR_RST"
    continue
  fi

  clean="$(printf "%s\n" "$out" | tr -d '\r')"
  mapfile -t ipv4s < <(printf "%s\n" "$clean" | extract_ips | grep -vE '^172\.29\.')

  total="${#ipv4s[@]}"
  declare -a known=() unknown=()

  for ip4 in "${ipv4s[@]}"; do
    if [[ -n "${NAME[$ip4]:-}" ]]; then
      known+=( "${NAME[$ip4]}" )
    else
      unknown+=( "$ip4" )
    fi
  done

  (( ${#known[@]} ))  && mapfile -t known   < <(printf "%s\n" "${known[@]}"   | awk 'NF' | sort -u)
  (( ${#unknown[@]} ))&& mapfile -t unknown < <(printf "%s\n" "${unknown[@]}" | awk 'NF' | sort -u)

  printf "%s — Clients: %d | Known: %d | Unknown: %d\n" \
         "$label" "$total" "${#known[@]}" "${#unknown[@]}"

  if ((${#known[@]})); then
    # adjust width to match your Conky min width; try 54 if you want wider
    wrap_list2 "  Connected: " "             " 45 "${known[@]}"
  else
    printf "  Connected: none\n"
  fi

  if ((${#unknown[@]})); then
    printf "  %sUnknown:%s\n" "$COLOR_RED" "$COLOR_RST"
    wrap_list2 "    " "    " 45 "${unknown[@]}"
  fi

  echo
done
