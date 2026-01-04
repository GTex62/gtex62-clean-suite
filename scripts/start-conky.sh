#!/usr/bin/env bash
# ~/.config/conky/gtex62-clean-suite/scripts/start-conky.sh

export PFSENSE_HOST="${PFSENSE_HOST:-192.168.40.1}"
export AP_IPS="${AP_IPS:-192.168.40.4,192.168.40.5,192.168.40.6}" # Override via AP_IPS env if needed
export AP_LABELS="${AP_LABELS:-Closet,Office,Great Room}" # Order must match AP_IPS


pkill -x conky 2>/dev/null || true

# Adjust gap_x for your monitor layout
# Example assumes Monitor #2 is on the right of primary display

# System info - left edge of 2nd monitor
conky -c ~/.config/conky/gtex62-clean-suite/widgets/sys-info.conky.conf &

# Network info below system info
conky -c ~/.config/conky/gtex62-clean-suite/widgets/net-sys.conky.conf &

# Weather center below date & time
conky -c ~/.config/conky/gtex62-clean-suite/widgets/weather.conky.conf &

# Date & time above weather
conky -c ~/.config/conky/gtex62-clean-suite/widgets/date-time.conky.conf &

# Calendar on top right
conky -c ~/.config/conky/gtex62-clean-suite/widgets/calendar.conky.conf &

#Notes on right edge
conky -c ~/.config/conky/gtex62-clean-suite/widgets/notes.conky.conf &

# Music widget center below weather
conky -c ~/.config/conky/gtex62-clean-suite/widgets/music.conky.conf &

# pfSense widget center bottom
conky -c ~/.config/conky/gtex62-clean-suite/widgets/pfsense.conky.conf &

# AP WBE530 widget next to Network info widget
#conky -c ~/.config/conky/gtex62-clean-suite/widgets/ap-wbe530.conky.conf &

# Lyrics widget
conky -c ~/.config/conky/gtex62-clean-suite/widgets/music-lyrics.conky.conf &
