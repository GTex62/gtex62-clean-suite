#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
GATE="${SCRIPT_DIR}/pf-ssh-gate.sh"
SSH_ERR_FILE="${HOME}/.cache/conky/pfsense/ssh_last_err"
SSH="ssh -o BatchMode=yes -o ConnectTimeout=5 -o ConnectionAttempts=1 -o ServerAliveInterval=5 -o ServerAliveCountMax=1 -o LogLevel=ERROR pf"
MODE="${1:-full}"
PI_SSH="ssh -o BatchMode=yes -o ConnectTimeout=5 -o ConnectionAttempts=1 -o ServerAliveInterval=5 -o ServerAliveCountMax=1 -o LogLevel=ERROR pi5"

pf_ssh() {
  if $SSH "$@"; then
    "$GATE" reset
    return 0
  fi

  printf '%s\n' "PF_SSH_FAIL" > "$SSH_ERR_FILE"
  "$GATE" trip "PF_SSH_FAIL"
  return 1
}

if ! "$GATE" allow; then
  gate_status="$("$GATE" status)"
  printf 'ssh_tripped=1\n'
  printf 'ssh_status=%s\n' "$gate_status"
  exit 0
fi

if [ "$MODE" = "full" ] || [ "$MODE" = "medium" ]; then
  echo "section=system"
  # shellcheck disable=SC2016
  pf_ssh 'upt=$(uptime); \
    echo "uptime=$upt"; \
    load_part="${upt##*load averages: }"; \
    if [ "$load_part" = "$upt" ]; then load_part="${upt##*load average: }"; fi; \
    if [ "$load_part" != "$upt" ]; then \
      l1=$(printf "%s" "$load_part" | cut -d, -f1 | tr -d " "); \
      l5=$(printf "%s" "$load_part" | cut -d, -f2 | tr -d " "); \
      l15=$(printf "%s" "$load_part" | cut -d, -f3 | tr -d " "); \
      echo "load_1=$l1"; \
      echo "load_5=$l5"; \
      echo "load_15=$l15"; \
    else \
      echo "load_1="; \
      echo "load_5="; \
      echo "load_15="; \
    fi; \
    physmem=$(sysctl -n hw.physmem 2>/dev/null); \
    ncpu=$(sysctl -n hw.ncpu 2>/dev/null); \
    echo "physmem_bytes=$physmem"; \
    echo "ncpu=$ncpu"; \
    top -b -n 1 | awk -v physmem="$physmem" '"'"'
    function to_mib(s,    v,u) {
      v = s
      gsub(/^[ 	]+|[ 	]+$/, "", v)
      u = substr(v, length(v), 1)
      if (u ~ /[KMG]/) {
        v = substr(v, 1, length(v) - 1)
      } else {
        u = "M"
      }
      v = v + 0
      if (u == "K") return v / 1024
      if (u == "G") return v * 1024
      return v
    }
    /^CPU:/ {
      for(i=2;i<=NF;i++) gsub("%","",$i);
      printf "cpu_user=%s\ncpu_nice=%s\ncpu_system=%s\ncpu_interrupt=%s\ncpu_idle=%s\n",$2,$4,$6,$8,$10
    }
    /^Mem:/  {
      print "mem_line=\"" $0 "\""
      active = ""; wired = ""; free = ""
      has_active = 0; has_wired = 0; has_free = 0
      for (i = 2; i <= NF; i++) {
        if ($(i + 1) ~ /^Active/) { active = to_mib($(i)); has_active = 1 }
        if ($(i + 1) ~ /^Wired/)  { wired = to_mib($(i)); has_wired = 1 }
        if ($(i + 1) ~ /^Free/)   { free = to_mib($(i)); has_free = 1 }
      }
      if (has_active) printf "mem_active_mb=%s\n", active; else print "mem_active_mb="
      if (has_wired)  printf "mem_wired_mb=%s\n", wired; else print "mem_wired_mb="
      if (has_free)   printf "mem_free_mb=%s\n", free; else print "mem_free_mb="
      if (has_active && has_wired && physmem > 0) {
        used_bytes = (active + wired) * 1024 * 1024
        printf "mem_used_pct=%.2f\n", (used_bytes / physmem) * 100
      } else {
        print "mem_used_pct="
      }
    }
    /^Swap:/ { print "swap_line=\"" $0 "\"" }
  '"'"'; \
    echo -n "hw_model="; sysctl -n hw.model 2>/dev/null'
fi

echo "section=interfaces"
# shellcheck disable=SC2016
pf_ssh 'for IF in igc1.40 igc1.10 igc1.20 igc1.30 igc0; do \
  netstat -I "$IF" -b -n | awk -v ifn="$IF" '"'"'
    NR==2 {
      printf "iface_%s_ibytes=%s\n", ifn, $8;
      printf "iface_%s_obytes=%s\n", ifn, $11
    }
  '"'"';
done'

if [ "$MODE" = "full" ] || [ "$MODE" = "medium" ]; then
  echo "section=gateway"
  # shellcheck disable=SC2016
  pf_ssh '
gw=$(route -n get -inet default 2>/dev/null | awk "/gateway:/{print \$2}");
if [ -n "$gw" ]; then
  if ping -c1 -t2 "$gw" >/dev/null 2>&1; then
    echo "gateway_online=1"
    echo "gateway_ip=$gw"
    echo "method=gateway"
  elif ping -c1 -t2 1.1.1.1 >/dev/null 2>&1; then
    echo "gateway_online=1"
    echo "gateway_ip=$gw"
    echo "method=internet"
  else
    echo "gateway_online=0"
    echo "gateway_ip=$gw"
    echo "method=none"
  fi
else
  if ping -c1 -t2 1.1.1.1 >/dev/null 2>&1; then
    echo "gateway_online=1"
    echo "gateway_ip="
    echo "method=internet"
  else
    echo "gateway_online=0"
    echo "gateway_ip="
    echo "method=none"
  fi
fi'
fi

if [ "$MODE" = "full" ] || [ "$MODE" = "slow" ]; then
  echo "section=pfblockerng"
  # shellcheck disable=SC2016
  pf_ssh '
IP_PACKETS=$(pfctl -vvsr 2>/dev/null | awk '"'"'
/label "USER_RULE: pfB_/ && $0 !~ /pfB_DNSBL_/ {flag=1}
flag && /^[[:space:]]*\[ Evaluations:/ {
  for (i=1;i<=NF;i++) if ($i=="Packets:") {p += $(i+1); break}
  flag=0
}
END{print p+0}
'"'"');
echo "pfb_ip_total=$IP_PACKETS"

DNSBL_PACKETS=$(sqlite3 /var/unbound/pfb_py_dnsbl.sqlite \
  "SELECT COALESCE(SUM(counter),0) FROM dnsbl;");
echo "pfb_dnsbl_total=$DNSBL_PACKETS"

RESOLVER_TOTAL=$(sqlite3 /var/unbound/pfb_py_resolver.sqlite \
  "SELECT COALESCE(totalqueries,0)+COALESCE(queries,0) FROM resolver WHERE row=0;");
echo "resolver_total=$RESOLVER_TOTAL"

DNSBL_PCT=$(awk -v d="$DNSBL_PACKETS" -v t="$RESOLVER_TOTAL" \
  '"'"'BEGIN { if (t>0) printf "%.2f", (d/t)*100; else print "0.00" }'"'"')
echo "pfb_dnsbl_pct=$DNSBL_PCT"
'

  echo "section=pihole"
  # shellcheck disable=SC2016
  $PI_SSH '
active=$(systemctl is-active pihole-FTL 2>/dev/null);
if [ "$active" = "active" ]; then
  echo "pihole_active=1"
else
  echo "pihole_active=0"
fi
read -r l1 l5 l15 _ < /proc/loadavg 2>/dev/null || true
echo "pihole_load1=${l1:-}"
echo "pihole_load5=${l5:-}"
echo "pihole_load15=${l15:-}"
total=$(sudo -n sqlite3 /etc/pihole/pihole-FTL.db "select value from counters where id=0;" 2>/dev/null)
blocked=$(sudo -n sqlite3 /etc/pihole/pihole-FTL.db "select value from counters where id=1;" 2>/dev/null)
domains=$(sudo -n sqlite3 /etc/pihole/gravity.db "select count(distinct domain) from gravity;" 2>/dev/null)
echo "pihole_total=${total:-}"
echo "pihole_blocked=${blocked:-}"
echo "pihole_domains=${domains:-}"
'
fi

gate_status="$("$GATE" status)"
if [[ "$gate_status" == TRIPPED* ]]; then
  printf 'ssh_tripped=1\n'
else
  printf 'ssh_tripped=0\n'
fi
printf 'ssh_status=%s\n' "$gate_status"
