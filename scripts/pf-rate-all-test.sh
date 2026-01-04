#!/usr/bin/env bash
set -euo pipefail

THEME="$HOME/.config/conky/gtex62-clean-suite/theme-pf.lua"
HOST=$(lua -e 'local T=dofile(os.getenv("HOME").."/.config/conky/gtex62-clean-suite/theme-pf.lua"); print(T.host)')
POLL=$(lua -e 'local T=dofile(os.getenv("HOME").."/.config/conky/gtex62-clean-suite/theme-pf.lua"); print(T.poll.fast)')
MODE=$(lua -e 'local T=dofile(os.getenv("HOME").."/.config/conky/gtex62-clean-suite/theme-pf.lua"); print(T.scale.mode)')
BASE=$(lua -e 'local T=dofile(os.getenv("HOME").."/.config/conky/gtex62-clean-suite/theme-pf.lua"); print(T.scale.log.base)')
MINN=$(lua -e 'local T=dofile(os.getenv("HOME").."/.config/conky/gtex62-clean-suite/theme-pf.lua"); print(T.scale.log.min_norm)')
labels=("INFRA" "HOME" "IOT" "GUEST" "WAN")

iface_for(){ lua -e "local T=dofile(os.getenv('HOME')..'/.config/conky/gtex62-clean-suite/theme-pf.lua'); print(T.ifaces.$1)" ;}
link_for(){  lua -e "local T=dofile(os.getenv('HOME')..'/.config/conky/gtex62-clean-suite/theme-pf.lua'); print(T.link_mbps.$1)" ;}

SSH="ssh -oBatchMode=yes admin@${HOST}"

declare -A i1 o1 IF LM
for L in "${labels[@]}"; do
  IF[$L]=$(iface_for "$L")
  LM[$L]=$(link_for "$L")
  read ib ob < <($SSH "netstat -I ${IF[$L]} -b -n | awk 'NR==2{print \$8, \$11}'")
  i1[$L]="$ib"; o1[$L]="$ob"
done

sleep "$POLL"

for L in "${labels[@]}"; do
  read i2 o2 < <($SSH "netstat -I ${IF[$L]} -b -n | awk 'NR==2{print \$8, \$11}'")
  dI=$(( i2>i1[$L] ? i2-i1[$L] : 0 ))
  dO=$(( o2>o1[$L] ? o2-o1[$L] : 0 ))
  in_mbps=$(awk -v b="$dI" -v s="$POLL" 'BEGIN{printf "%.3f", (b*8)/(s*1000*1000)}')
  out_mbps=$(awk -v b="$dO" -v s="$POLL" 'BEGIN{printf "%.3f", (b*8)/(s*1000*1000)}')
  lin_in=$(awk -v m="$in_mbps" -v L="${LM[$L]}" 'BEGIN{if(L<0.001){print 0}else{p=m/L; if(p<0)p=0; if(p>1)p=1; printf "%.4f", p}}')
  lin_out=$(awk -v m="$out_mbps" -v L="${LM[$L]}" 'BEGIN{if(L<0.001){print 0}else{p=m/L; if(p<0)p=0; if(p>1)p=1; printf "%.4f", p}}')

  if [[ "$lin_in" == "0.0000" ]]; then
    pct_in="0.0000"
  else
    pct_in=$(awk -v p="$lin_in" -v base="$BASE" -v mn="$MINN" -v mode="$MODE" 'BEGIN{
      if (mode=="log") { if (p<mn) p=mn; if (p>1) p=1; printf "%.4f", log(1+(base-1)*p)/log(base) }
      else if (mode=="sqrt") { if (p<0) p=0; if (p>1) p=1; printf "%.4f", sqrt(p) }
      else { if (p<0) p=0; if (p>1) p=1; printf "%.4f", p }
    }')
  fi
  if [[ "$lin_out" == "0.0000" ]]; then
    pct_out="0.0000"
  else
    pct_out=$(awk -v p="$lin_out" -v base="$BASE" -v mn="$MINN" -v mode="$MODE" 'BEGIN{
      if (mode=="log") { if (p<mn) p=mn; if (p>1) p=1; printf "%.4f", log(1+(base-1)*p)/log(base) }
      else if (mode=="sqrt") { if (p<0) p=0; if (p>1) p=1; printf "%.4f", sqrt(p) }
      else { if (p<0) p=0; if (p>1) p=1; printf "%.4f", p }
    }')
  fi

  printf "%s if=%s link=%sMbps mode=%s raw_in=%.3f raw_out=%.3f pct_in=%.4f pct_out=%.4f\n" \
    "$L" "${IF[$L]}" "${LM[$L]}" "$MODE" "$in_mbps" "$out_mbps" "$pct_in" "$pct_out"
done
