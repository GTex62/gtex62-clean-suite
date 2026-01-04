#!/usr/bin/env bash
set -euo pipefail

THEME="$HOME/.config/conky/gtex62-clean-suite/theme-pf.lua"
HOST=$(lua -e 'local T=dofile(os.getenv("HOME").."/.config/conky/gtex62-clean-suite/theme-pf.lua"); print(T.host)')
IFACE=$(lua -e 'local T=dofile(os.getenv("HOME").."/.config/conky/gtex62-clean-suite/theme-pf.lua"); print(T.ifaces.INFRA)')
LMbps=$(lua -e 'local T=dofile(os.getenv("HOME").."/.config/conky/gtex62-clean-suite/theme-pf.lua"); print(T.link_mbps.INFRA)')
MODE=$(lua -e 'local T=dofile(os.getenv("HOME").."/.config/conky/gtex62-clean-suite/theme-pf.lua"); print(T.scale.mode)')
BASE=$(lua -e 'local T=dofile(os.getenv("HOME").."/.config/conky/gtex62-clean-suite/theme-pf.lua"); print(T.scale.log.base)')
MINN=$(lua -e 'local T=dofile(os.getenv("HOME").."/.config/conky/gtex62-clean-suite/theme-pf.lua"); print(T.scale.log.min_norm)')

SSH="ssh -oBatchMode=yes admin@${HOST}"

read i1 o1 < <($SSH "netstat -I $IFACE -b -n | awk 'NR==2{print \$8, \$11}'")
sleep 2
read i2 o2 < <($SSH "netstat -I $IFACE -b -n | awk 'NR==2{print \$8, \$11}'")

dI=$(( i2>i1 ? i2-i1 : 0 ))
dO=$(( o2>o1 ? o2-o1 : 0 ))

in_mbps=$(awk -v b="$dI" 'BEGIN{printf "%.3f", (b*8)/(2*1000*1000)}')
out_mbps=$(awk -v b="$dO" 'BEGIN{printf "%.3f", (b*8)/(2*1000*1000)}')

lin_in=$(awk -v m="$in_mbps" -v L="$LMbps" 'BEGIN{if(L<0.001){print 0}else{p=m/L; if(p<0)p=0; if(p>1)p=1; printf "%.4f", p}}')
lin_out=$(awk -v m="$out_mbps" -v L="$LMbps" 'BEGIN{if(L<0.001){print 0}else{p=m/L; if(p<0)p=0; if(p>1)p=1; printf "%.4f", p}}')

log_in=$(awk -v p="$lin_in" -v base="$BASE" -v mn="$MINN" 'BEGIN{ if (p<mn) p=mn; if (p>1) p=1; printf "%.4f", log(1+(base-1)*p)/log(base) }')
log_out=$(awk -v p="$lin_out" -v base="$BASE" -v mn="$MINN" 'BEGIN{ if (p<mn) p=mn; if (p>1) p=1; printf "%.4f", log(1+(base-1)*p)/log(base) }')

if [[ "$MODE" == "log" ]]; then
  pct_in="$log_in"; pct_out="$log_out"
else
  pct_in="$lin_in"; pct_out="$lin_out"
fi

printf "iface=INFRA ifname=%s link=%.0fMbps mode=%s\n" "$IFACE" "$LMbps" "$MODE"
printf "raw_in_mbps=%.3f raw_out_mbps=%.3f\n" "$in_mbps" "$out_mbps"
printf "pct_in=%.4f pct_out=%.4f (0..1 of arc)\n" "$pct_in" "$pct_out"
