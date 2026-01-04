--[[
  ~/.config/conky/gtex62-clean-suite/theme-pf.lua
  pfSense widget theme configuration

  This table is read by lua/pf_widget.lua via:
      local T = dofile(os.getenv("HOME") ..
        "/.config/conky/gtex62-clean-suite/theme-pf.lua")

  It provides:
    • Typography and base colors specific to the pfSense widget
    • Refresh cadence and pfSense host/interface map
    • Link speeds (Mbps) and visual scaling floors/curves
    • Arc geometry, markers, and end labels (“IN” / “OUT”)
    • Baseline (“hline”) and the info line under the arc
    • Gateway status label (ONLINE / OFFLINE) centered above baseline
    • Debug toggles for development

  Notes:
    • Keys/paths match pf_widget.lua; do not rename sections (T.pf.* etc.).
    • Make visual/layout tweaks here; avoid code changes in the widget.
]]

local T = {}

----------------------------------------------------------------
-- Typography & basic colors
----------------------------------------------------------------
T.fonts = {
  regular = "Inter",
  mono    = "JetBrainsMono Nerd Font Mono",
  bold    = "Inter Bold",
}

T.sizes = {
  title     = 20,
  label     = 14,
  value     = 16,
  arc_thick = 6,
}

T.colors = {
  bg      = { 0.06, 0.06, 0.08, 1.0 }, --                        gray7
  text    = { 0.90, 0.92, 0.96, 1.0 }, --                        lavender
  accent  = { 1.00, 0.00, 0.00, 1.0 }, -- headers/markers        red
  good    = { 0.20, 0.80, 0.40, 1.0 }, -- online/ok              MediumSeaGreen
  warn    = { 1.00, 0.70, 0.20, 1.0 }, -- caution                goldenrod1
  bad     = { 0.95, 0.30, 0.25, 1.0 }, -- offline/error          tomato2
  arc_in  = { 0.35, 0.75, 1.00, 1.0 }, -- inbound arcs           SteelBlue1
  arc_out = { 1.00, 0.55, 0.25, 1.0 }, -- outbound arcs          sienna1
}

----------------------------------------------------------------
-- Refresh cadence
----------------------------------------------------------------
T.poll = {
  fast   = 1,  -- CPU/MEM, interface rates
  medium = 60, -- bytes totals, gateway
  slow   = 90, -- pfBlockerNG counts
}

----------------------------------------------------------------
-- pfSense host & interface map
----------------------------------------------------------------
T.host = os.getenv("PFSENSE_HOST") or "192.168.1.1"

T.ifaces = {
  INFRA = "igc1.40",
  HOME  = "igc1.10",
  IOT   = "igc1.20",
  GUEST = "igc1.30",
  WAN   = "igc0",
}

----------------------------------------------------------------
-- Link speeds (Mbps) for normalization
----------------------------------------------------------------
T.link_mbps = {
  INFRA = 700,
  HOME  = 700,
  IOT   = 700,
  GUEST = 700,
  WAN   = 700,
}

----------------------------------------------------------------
-- Optional: separate link caps for normalization (IN vs OUT)
-- If present, the widget will prefer these over T.link_mbps.*
----------------------------------------------------------------
T.link_mbps_in = {
  WAN   = 600, -- Per tests (~589 Mbps down), make 100% ≈ 700 Mbps headroom
  INFRA = 100,
  HOME  = 100,
  IOT   = 100,
  GUEST = 50,
}

T.link_mbps_out = {
  WAN   = 50, -- ~50 Mbps is a sensible cap
  INFRA = 100,
  HOME  = 100,
  IOT   = 100,
  GUEST = 100,
}


----------------------------------------------------------------
-- Scaling & floors (visual response curve)
-- mode: "linear" | "log" | "sqrt"
----------------------------------------------------------------
T.scale = {
  mode = "sqrt",

  log = {
    base     = 4.0,
    min_norm = 0.0008,
  },

  sqrt = {
    gamma = 0.35, --0.25-0.4:very sensitive, 0.45-0.6:balanced, 0.7-0.8:conservative
  },

  -- Per-interface floors (Mbps) to avoid tiny idle wiggles
  floors_mbps = {
    INFRA = 0,
    HOME  = 0,
    IOT   = 0,
    GUEST = 0,
    WAN   = 0,
  },

  -- Clamp after scaling (0..1)
  clamp_pct = { min = 0.0, max = 1.0 },
}

----------------------------------------------------------------
-- pfSense arc + marker theme (geometry + appearance)
----------------------------------------------------------------
T.pf = {
  arc = {
    dx      = 0,                         -- offset from chosen center (code uses cx+dx, cy+dy)
    dy      = 0,
    r       = 380,                       -- radius (px)
    start   = 180,                       -- left end (deg)
    ["end"] = 0,                         -- right end (deg)
    color   = { 0.65, 0.65, 0.65, 1.0 }, -- base arc stroke   gray65
    width   = 2,                         -- arc stroke width
  },

  -- Concentric arc spacing (centerline to centerline)
  deltaR = 36,

  -- 0.0 = concentric, 1.0 = apex-anchored
  anchor_strength = .5,

  -- Per-arc overrides (future use)
  arcs = {},

  -- Markers (left IN = filled; right OUT = hollow)
  markers = {
    in_filled = {
      color  = { 1.00, 0.00, 0.00, 1.00 }, -- red fill
      radius = 12,
    },
    out_hollow = {
      color  = { 1.00, 0.00, 0.00, 1.00 }, -- red outline
      radius = 12,
      stroke = 3,
    },
  },

  -- Per-arc marker colors (WAN inherits markers.* by default)
  marker_colors = {
    HOME  = { 0.60, 0.60, 0.60, 1.0 }, -- #999999
    IOT   = { 0.40, 0.40, 0.40, 1.0 }, -- #666666
    GUEST = { 0.25, 0.25, 0.25, 1.0 }, -- #404040
    INFRA = { 1.00, 1.00, 1.00, 1.0 }, -- #FFFFFF
  },
}

----------------------------------------------------------------
-- Load average normalization (center meters)
----------------------------------------------------------------
T.pf.load = {
  window = 5,     -- 1 | 5 | 15
  cores  = "auto" -- "auto" or number
}

T.pf.load_thresholds = {
  enabled = false,
  ok      = 0.50,
  warn    = 1.00,
  crit    = 1.50,
}

----------------------------------------------------------------
-- Labels at arc ends (“IN” / “OUT”)
----------------------------------------------------------------
T.pf.labels = {
  font     = (T.fonts and T.fonts.regular) or "DejaVu Sans",
  size     = 12,
  color    = { 0.85, 0.85, 0.85, 1.0 }, -- gray85

  -- Offsets (pixels) from arc endpoints (left="IN", right="OUT")
  dx_left  = -8,
  dy_left  = 30,
  dx_right = -08,
  dy_right = 30,

  text_in  = "DN",
  text_out = "UP",
}

----------------------------------------------------------------
-- Arc name labels (dash leader + name at left endpoints)
----------------------------------------------------------------
T.pf.arc_names = {
  enabled   = true,
  dash_char = "-",
  dash_gap  = 0,
  dx        = 5,
  dy        = 5,
  font      = (T.fonts and T.fonts.mono) or "DejaVu Sans Mono",
  size      = 16,
  color     = (T.colors and T.colors.text) or { 0.85, 0.85, 0.85, 1.0 },

  per_arc   = {
    WAN   = { dash_count = 14, text = "WAN" },
    HOME  = { dash_count = 18, text = "HOME" },
    IOT   = { dash_count = 26, text = "IoT" },
    GUEST = { dash_count = 28, text = "GUEST" },
    INFRA = { dash_count = 34, text = "INFRA" },
  },
}

----------------------------------------------------------------
-- Top-of-arc label (static)
----------------------------------------------------------------
T.pf.top_label = {
  enabled = true,   -- master toggle
  text    = "100%", -- static text
  dy      = 94,     -- pixels BELOW the arc line (positive = down)
  -- font/size/color will reuse T.pf.labels.* so it matches IN/OUT
}

----------------------------------------------------------------
-- Smoothing (EMA) for rates
----------------------------------------------------------------
T.pf.smoothing = {
  alpha = 0.35, -- higher = snappier, lower = smoother (0.15–0.45 is a nice range)
}

----------------------------------------------------------------
-- Baseline (“hline”) under the arc
----------------------------------------------------------------
T.pf.hline = {
  length = 820,                       -- total length in px (wider than arc base)
  width  = 1,                         -- stroke thickness
  color  = { 0.85, 0.85, 0.90, 0.9 }, -- RGBA   gray87 with slight transparency

  -- Positioning (nil = auto-center on arc; use dy to nudge):
  x      = nil,
  y      = nil,
  dy     = 50,
}

----------------------------------------------------------------
-- Center meters: LOAD and MEM% (vertical bars under the apex)
----------------------------------------------------------------
T.pf.center_meters = {
  enabled       = true,

  -- Positioning relative to the arc center (cx, cy)
  dx            = 0,    -- horizontal group offset
  dy            = -240, -- vertical offset downward from arc center

  -- Bar geometry
  height        = 110, -- bar height (px)
  width         = 60,  -- each bar width (px)
  gap           = 50,  -- space between CPU and MEM bars (px)
  radius        = 0,   -- corner roundness (px)
  stroke        = 2,   -- frame thickness (px)

  curve         = {
    gamma       = 0.5, -- 0.5–0.8 = gentle ease (1.0 = off)
    min_pct     = 0.0, -- small floor so tiny usage still shows
    cpu_min_pct = 0.0, -- per-meter overrides (optional)
    mem_min_pct = 0.0,
  },

  -- Colors
  color_frame   = { 0.85, 0.85, 0.90, 0.9 }, -- frame (gray87 with slight transparency)
  color_back    = { 0.12, 0.12, 0.14, 0.0 }, -- bar background (gray13)
  color_fill    = { 1.00, 0.80, 0.10, 1.0 }, -- fill (goldenrod1)

  -- Labels under the bars
  label_size    = 16,
  label_color   = { 0.95, 0.97, 0.99, 1.0 }, -- AliceBlue (White)
  label_dx      = -6,                        -- px nudge for labels (negative = left, adjust to taste)
  label_dx_load = 14,                        -- optional override for LOAD label
  -- label_dx_mem = -6,                    -- optional override for MEM label
  cpu_label     = "CPU%",
  mem_label     = "MEM%",

  -- Vertical separator between bars
  separator     = {
    enabled = true,
    width   = 2,
    dy      = 0,                         -- offset relative to bars
    color   = { 0.50, 0.50, 0.55, 0.9 }, -- gray52
    length  = 160,                       -- px; remove or nil to match bar height
  },

  -- Optional smoothing just for these meters
  smoothing     = { alpha = 0.35 },
}

----------------------------------------------------------------
-- Nameplate (static text under center meters)
----------------------------------------------------------------
T.pf.nameplate = {
  enabled = true,
  text    = "V1211",
  dx      = 0,
  dy      = 15,
  font    = (T.fonts and T.fonts.regular) or "DejaVu Sans",
  size    = 14,
  color   = { 0.49, 0.49, 0.49, 1.0 }, -- gray49
  align   = "center",
}


----------------------------------------------------------------
-- Gateway status label (ONLINE / OFFLINE) – centered above baseline
----------------------------------------------------------------
T.pf.gateway_label = {
  enabled   = true,      -- master toggle
  size      = 16,        -- font size (px)
  dy        = 12,        -- pixels ABOVE the baseline (increase to move up)
  weight    = "regular", -- "regular" | "bold"

  -- Text for states
  text_ok   = "ONLINE",
  text_bad  = "OFFLINE",

  -- Optional explicit colors. If nil, widget falls back to T.colors.good/bad.
  -- Example to force gray for ONLINE:
  color_ok  = { 0.49, 0.49, 0.49, 1.0 }, -- gray49
  -- color_ok  = nil,
  color_bad = nil,
}

----------------------------------------------------------------
-- Info line (under the baseline)
----------------------------------------------------------------
T.pf.infoline = {
  enabled     = true,
  dx          = 5,  -- shift from LEFT end of baseline (px)
  dy          = 24, -- vertical gap under the baseline (px)
  size        = 17,
  sep         = "  |  ",
  label_color = { 0.49, 0.49, 0.49, 1.0 }, -- gray49
  value_color = { 0.95, 0.97, 0.99, 1.0 }, -- AliceBlue (White)
}

----------------------------------------------------------------
-- Totals table (cumulative bytes per interface)
----------------------------------------------------------------
T.pf.totals_table = {
  enabled      = true,
  dx           = -38,
  dy           = 120,
  font         = (T.fonts and T.fonts.mono) or "DejaVu Sans Mono",
  size_header  = 17,
  size_body    = 16,
  color_header = { 0.60, 0.60, 0.60, 1.0 }, -- darkgray
  color_label  = { 0.49, 0.49, 0.49, 1.0 }, -- gray49
  color_value  = { 0.95, 0.97, 0.99, 1.0 }, -- AliceBlue (White)

  label_col_w  = 120,
  data_col_w   = 110,
  header_h     = 20,
  row_h        = 18,
  row_gap      = 10,

  headers      = { "WAN", "HOME", "IoT", "GUEST", "INFRA" },
  row_labels   = { ["in"] = "DN", ["out"] = "UP" },
}

----------------------------------------------------------------
-- Status block (pfBlockerNG + Pi-hole)
----------------------------------------------------------------
T.pf.status_block = {
  enabled     = true,
  dx          = 0,
  dy          = 260,
  line_gap    = 30,
  font        = (T.fonts and T.fonts.regular) or "DejaVu Sans",
  size        = 19,
  label_color = { 0.49, 0.49, 0.49, 1.0 }, -- gray49
  value_color = { 0.95, 0.97, 0.99, 1.0 }, -- AliceBlue (White)
  field_sep   = " | ",

  pfb         = {
    enabled    = true,
    prefix     = "pfBlockerNG:",
    show_total = true,
  },

  pihole      = {
    enabled      = true,
    prefix       = "Pi-hole:",
    host         = "pi5",
    load_window  = 15,
    decimals_pct = 2,
  },
}

----------------------------------------------------------------
-- Debug & development options
----------------------------------------------------------------
T.pf.debug = {
  show_center = false, -- draw a tiny cross at the arc center
  text_block  = false, -- show old five-line reader text + DBG line (off by default)
}

----------------------------------------------------------------
-- Return table consumed by pf_widget.lua
----------------------------------------------------------------
return T
