---@diagnostic disable: undefined-global, cast-local-type, assign-type-mismatch, need-check-nil, param-type-mismatch

-- ~/.config/conky/gtex62-clean-suite/lua/music.lua
-- Music “now-playing horizon”: exact mirror of weather arc (smile),
-- left→right progress trail + marker, endpoint time labels (centered),
-- artist/title with dx/dy, album art inside the arc + album name.
-- (HR line comes from your vline.png image in conky.text, not drawn here.)

--------------------------
-- Cairo availability
--------------------------
local has_cairo = pcall(require, "cairo") -- enables global cairo_* funcs in Conky

--------------------------
-- THEME loader
--------------------------
local HOME = os.getenv("HOME") or ""
local THEME = (function()
  local path = HOME .. "/.config/conky/gtex62-clean-suite/theme.lua"
  local ok, t = pcall(dofile, path)
  if ok and type(t) == "table" then return t end
  if type(theme) == "table" then return theme end
  return {}
end)()

-- Safe nested lookup
local function tget(root, dotted)
  local node = root
  for key in string.gmatch(dotted or "", "[^%.]+") do
    if type(node) ~= "table" then return nil end
    node = node[key]
  end
  return node
end
local function tgetd(path, default)
  local v = tget(THEME, path)
  if v == nil then return default end
  return v
end

--------------------------
-- Helpers
--------------------------
local function clamp01(x) if x < 0 then return 0 elseif x > 1 then return 1 else return x end end
local function deg2rad(d) return (math.pi / 180) * d end
local function set_rgba_hex(cr, hex, a)
  hex = (hex or "FFFFFF"):gsub("#", "")
  local r = tonumber(hex:sub(1, 2), 16) or 255
  local g = tonumber(hex:sub(3, 4), 16) or 255
  local b = tonumber(hex:sub(5, 6), 16) or 255
  cairo_set_source_rgba(cr, r / 255, g / 255, b / 255, a or 1)
end

-- Weather geometry (EXACTLY as your weather widget computes it)
local function icon_geom_weather()
  local x = tonumber(tget(THEME, "weather.icon.x")) or 196
  local y = tonumber(tget(THEME, "weather.icon.y")) or 70
  local w = tonumber(tget(THEME, "weather.icon.w")) or 96
  return x, y, w
end
local function arc_geom_weather()
  local dx   = tonumber(tget(THEME, "weather.arc.dx")) or 160
  local dy   = tonumber(tget(THEME, "weather.arc.dy")) or 100
  local r    = tonumber(tget(THEME, "weather.arc.r")) or 170
  local sdeg = tonumber(tget(THEME, "weather.arc.start")) or 180
  local edeg = tonumber(tget(THEME, "weather.arc.end")) or 0
  return dx, dy, r, sdeg, edeg
end
local function get_arc_geometry_weather()
  -- cx = icon_x + (icon_w/2) + dx ; cy = icon_y + (icon_w/2) + dy
  local ix, iy, iw = icon_geom_weather()
  local dx, dy, r, sdeg, edeg = arc_geom_weather()
  local cx = ix + (iw / 2) + dx
  local cy = iy + (iw / 2) + dy
  return cx, cy, r, sdeg, edeg
end


------------------------------------------------------------
-- Visibility helper with theme toggle
-- • If hide_when_inactive == false → always visible
-- • If true → visible while Playing/Paused; hide N seconds after stopped
------------------------------------------------------------
local MUSIC_LAST_SEEN = os.time()

function conky_music_visible()
  local cfg_hide = (THEME and THEME.music and THEME.music.hide_when_inactive)
  if cfg_hide == false then
    return "1"
  end

  local now = os.time()
  local status = ""
  local f = io.popen("playerctl status 2>/dev/null")
  if f then
    status = f:read("*l") or ""; f:close()
  end

  if status == "Playing" or status == "Paused" then
    MUSIC_LAST_SEEN = now
    return "1"
  end

  local threshold = tonumber(THEME and THEME.music and THEME.music.idle_hide_after_s) or 10
  if (now - MUSIC_LAST_SEEN) < threshold then
    return "1"
  end
  return "0"
end

--------------------------
-- Player meta (playerctl)
--------------------------
local function read_cmd(cmd)
  local f = io.popen(cmd); if not f then return nil end
  local out = f:read("*a"); f:close()
  if not out or out == "" then return nil end
  return (out:gsub("%s+$", ""))
end

-- Returns volume as a fraction 0..1 (or nil if unknown)
local function get_volume_frac()
  -- Prefer playerctl (returns 0.0..1.0 or sometimes 0..100)
  local out = read_cmd("playerctl volume 2>/dev/null")
  if out and out ~= "" then
    local v = tonumber(out)
    if v then
      if v > 1 then v = v / 100 end
      if v < 0 then v = 0 elseif v > 1 then v = 1 end
      return v
    end
  end

  -- Fallback: PulseAudio/PipeWire via pactl (parse first NN%)
  local pac = read_cmd("pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null")
  if pac and pac ~= "" then
    local pct = pac:match("(%d+)%%")
    if pct then
      local v = tonumber(pct) / 100
      if v then
        if v < 0 then v = 0 elseif v > 1 then v = 1 end
        return v
      end
    end
  end

  return nil
end

-- Returns true/false if muted known, or nil if unknown
local function get_is_muted()
  -- pactl works for PulseAudio/PipeWire
  local out = read_cmd("pactl get-sink-mute @DEFAULT_SINK@ 2>/dev/null")
  if out and out ~= "" then
    if out:match("yes") then return true end
    if out:match("no") then return false end
  end
  return nil
end


-- Normalize player times: position (s) -> ms, length (µs) -> ms
local function get_player_meta()
  local artist = read_cmd("playerctl metadata xesam:artist 2>/dev/null") or ""
  local title  = read_cmd("playerctl metadata xesam:title  2>/dev/null") or ""
  local album  = read_cmd("playerctl metadata xesam:album  2>/dev/null") or ""

  -- position is returned in *seconds* (float)
  local pos_ms = 0
  do
    local pos_s = read_cmd("playerctl position 2>/dev/null")
    if pos_s and pos_s ~= "" then
      local p = tonumber(pos_s) or 0
      pos_ms = math.floor(p * 1000 + 0.5)
    end
  end

  -- mpris:length is returned in *microseconds*
  local len_ms = 0
  do
    local len_us_str = read_cmd("playerctl metadata mpris:length 2>/dev/null")
    if len_us_str and len_us_str ~= "" then
      local us = tonumber(len_us_str) or 0
      len_ms = math.floor(us / 1000 + 0.5)
    end
  end

  -- Guard against weirdness (e.g., len missing or less than pos)
  if len_ms < pos_ms then len_ms = pos_ms end

  return {
    artist = artist,
    title  = title,
    album  = album,
    pos_ms = pos_ms,
    len_ms = len_ms
  }
end
-- Format milliseconds as M:SS
local function fmt_clock_ms(ms)
  if not ms or ms <= 0 or ms ~= ms then return "0:00" end
  local s = math.floor(ms / 1000 + 0.5)
  local m = math.floor(s / 60); s = s % 60
  return string.format("%d:%02d", m, s)
end

--------------------------
-- Cover art support (for ${lua_parse music_cover})
--------------------------
local COVER_CACHE = (HOME .. "/.cache/conky/nowplaying_cover.png")

local function _read_cmd_simple(cmd)
  local f = io.popen(cmd); if not f then return nil end
  local out = f:read("*a"); f:close()
  if not out or out == "" then return nil end
  return (out:gsub("%s+$", ""))
end
local function _get_art_url()
  local url = _read_cmd_simple("playerctl metadata mpris:artUrl 2>/dev/null")
  if url and url ~= "" then return url end
  return nil
end
local function _ensure_cover_cached()
  local url = _get_art_url()
  if not url or url == "" then return nil end

  if url:match("^file://") then
    local path = url:gsub("^file://", "")
    os.execute(string.format("cp -f %q %q", path, COVER_CACHE))
    return COVER_CACHE
  end
  if url:match("^https?://") then
    os.execute(string.format("curl -LfsS %q -o %q", url, COVER_CACHE))
    return COVER_CACHE
  end

  return nil
end


--------------------------
-- Main draw
--------------------------
function conky_music_draw()
  if not has_cairo or not conky_window then return "" end

  -- Cairo surface/context (global API)
  local cs = cairo_xlib_surface_create(
    conky_window.display,
    conky_window.drawable,
    conky_window.visual,
    conky_window.width,
    conky_window.height
  )
  local cr = cairo_create(cs)

  cairo_save(cr)
  cairo_new_path(cr)

  -- Geometry: IDENTICAL to weather arc
  local cx, cy, r, ARC_START, ARC_END = get_arc_geometry_weather()

  -- Colors / styles
  local base_col                      = tgetd("music.arc.base_color", tgetd("weather.arc.color", "A0A0A0"))
  local progress_col                  = tgetd("music.arc.progress_color", tgetd("weather.sun.color", "FFFF00"))
  local line_alpha                    = 1.0
  local line_width                    = tonumber(tget(THEME, "music.baseline.weight")) or 2

  -- Text theming
  local char_px                       = tonumber(tget(THEME, "char_px")) or 7
  local font_base                     = (tgetd("font", "DejaVu Sans Mono"):gsub(":size=%d+", ""))

  -- Metadata / timing
  local meta                          = get_player_meta()

  -- update/clear cover art based on player status
  do
    local f = io.popen("playerctl status 2>/dev/null")
    local st = f and (f:read("*l") or "") or ""
    if f then f:close() end

    if st == "Playing" or st == "Paused" then
      if type(_ensure_cover_cached) == "function" then _ensure_cover_cached() end
    else
      -- player stopped/closed → remove cached image so it won’t linger
      local ok = os.remove(COVER_CACHE)
      -- (ok may be nil if file didn’t exist; that’s fine)
    end
  end


  local pos  = meta.pos_ms
  local len  = meta.len_ms
  local frac = (len > 0) and clamp01(pos / len) or 0
  local function lerp(a, b, t) return a + (b - a) * t end

  ------------------------------------------------------------
  -- Draw the mirrored arc via vertical flip around baseline y=cy
  -- (keeps endpoints/length identical; paints only the played segment;
  --  always uses the *short* path between angles)
  ------------------------------------------------------------
  cairo_save(cr)
  cairo_translate(cr, 0, 2 * cy)
  cairo_scale(cr, 1, -1)

  -- helpers (local to this block)
  local function norm360(d)
    d = d % 360
    if d < 0 then d = d + 360 end
    return d
  end

  local function short_diff(a0, a1)
    -- shortest signed angular diff from a0 to a1 in (-180, 180]
    local d = (a1 - a0) % 360
    if d > 180 then d = d - 360 end
    return d
  end

  local function short_arc(cr_, cx_, cy_, r_, deg0, deg1)
    -- draw along the *short* path from deg0 to deg1
    local a0 = norm360(deg0)
    local a1 = norm360(deg1)
    local d  = (a1 - a0) % 360
    if d == 0 then
      -- identical; nothing to stroke
      return
    elseif d <= 180 then
      cairo_arc(cr_, cx_, cy_, r_, deg2rad(a0), deg2rad(a1))
    else
      cairo_arc_negative(cr_, cx_, cy_, r_, deg2rad(a0), deg2rad(a1))
    end
    cairo_stroke(cr_)
  end

  -- 1) Full arc baseline (short path between start/end)
  cairo_set_line_width(cr, line_width)
  set_rgba_hex(cr, base_col, line_alpha)
  short_arc(cr, cx, cy, r, ARC_START, ARC_END)

  -- 2) Progress trail (left → current) along the same short path
  if frac > 0 then
    set_rgba_hex(cr, progress_col, line_alpha)
    -- interpolate along the *short* angular path
    local dshort   = short_diff(ARC_START, ARC_END) -- signed (-180,180]
    local prog_deg = ARC_START + dshort * frac      -- current angle
    if prog_deg ~= ARC_START then
      short_arc(cr, cx, cy, r, ARC_START, prog_deg)
    end
  end

  -- 3) Progress marker circle at current angle (inside flipped block)
  do
    local dshort   = short_diff(ARC_START, ARC_END)
    local prog_deg = ARC_START + dshort * frac
    local theta    = deg2rad(prog_deg)

    local mx       = cx + r * math.cos(theta)
    -- NOTE: inside the flipped context use **+** sin, not minus
    local my       = cy + r * math.sin(theta)

    local d        = tonumber(tget(THEME, "music.marker.diameter")) or 10
    local sc       = tgetd("music.marker.color", progress_col)
    set_rgba_hex(cr, sc, 1.0)
    cairo_arc(cr, mx, my, d / 2, 0, 2 * math.pi)
    cairo_fill(cr)
  end

  -- 3b) Volume marker (red circle controlled by theme.music.volume_marker)
  do
    local v = get_volume_frac()
    if v then
      local dshort      = short_diff(ARC_START, ARC_END)
      local vdeg        = ARC_START + dshort * v
      local theta       = deg2rad(vdeg)

      -- still inside flipped context: use +sin
      local vx          = cx + r * math.cos(theta)
      local vy          = cy + r * math.sin(theta)

      local d           = tonumber(tget(THEME, "music.volume_marker.diameter")) or 16
      local base_col    = tgetd("music.volume_marker.color", "FF0000")
      local base_alpha  = tonumber(tget(THEME, "music.volume_marker.alpha")) or 1.0

      -- mute behavior
      local muted_mode  = tgetd("music.volume_marker.muted_mode", "dim") -- hide|dim|normal
      local muted_alpha = tonumber(tget(THEME, "music.volume_marker.muted_alpha")) or 0.35
      local is_muted    = get_is_muted()

      if is_muted == true and muted_mode == "hide" then
        -- skip drawing entirely
      else
        local fa = base_alpha
        if is_muted == true and muted_mode == "dim" then
          fa = muted_alpha
        end

        -- fill
        set_rgba_hex(cr, base_col, fa)
        cairo_arc(cr, vx, vy, d / 2, 0, 2 * math.pi)
        cairo_fill(cr)

        -- optional outline
        local ol_col   = tget(THEME, "music.volume_marker.outline_color")
        local ol_alpha = tonumber(tget(THEME, "music.volume_marker.outline_alpha"))
        local ol_w     = tonumber(tget(THEME, "music.volume_marker.outline_width"))
        if ol_col and ol_w and ol_w > 0 then
          set_rgba_hex(cr, ol_col, ol_alpha or fa)
          cairo_set_line_width(cr, ol_w)
          cairo_arc(cr, vx, vy, (d / 2) - (ol_w / 2), 0, 2 * math.pi)
          cairo_stroke(cr)
        end
      end
    end
  end



  cairo_restore(cr)

  ------------------------------------------------------------
  -- Time labels at mirrored endpoints (centered on endpoints)
  ------------------------------------------------------------
  do
    local label_pt  = tonumber(tget(THEME, "music.time_labels.pt")) or 10
    local label_col = tgetd("music.time_labels.color", "A0A0A0")
    local dy_lbl    = tonumber(tget(THEME, "music.time_labels.dy")) or 14
    local lx_off    = tonumber(tget(THEME, "music.time_labels.lx_offset")) or 0
    local rx_off    = tonumber(tget(THEME, "music.time_labels.rx_offset")) or 0
    local char_px   = tonumber(tget(THEME, "char_px")) or 7

    cairo_select_font_face(cr, (tgetd("font", "DejaVu Sans Mono"):gsub(":size=%d+", "")), 0, 0)
    cairo_set_font_size(cr, label_pt)
    set_rgba_hex(cr, label_col, 1.0)

    -- arc endpoints (in unflipped coords)
    local sx = cx + r * math.cos(deg2rad(ARC_START))
    local sy = cy - r * math.sin(deg2rad(ARC_START))
    local ex = cx + r * math.cos(deg2rad(ARC_END))
    local ey = cy - r * math.sin(deg2rad(ARC_END))

    local function center_on_x(x, text)
      local w = (#(text or "")) * char_px
      return x - (w / 2)
    end

    local played_str = fmt_clock_ms(pos)
    local remain_str = (len > 0) and ("-" .. fmt_clock_ms(len - pos)) or "-0:00"

    -- labels sit below the arc: mirror the Y to the smile side
    cairo_move_to(cr, center_on_x(sx, played_str) + lx_off, (2 * cy - sy) + dy_lbl)
    cairo_show_text(cr, played_str)

    cairo_move_to(cr, center_on_x(ex, remain_str) + rx_off, (2 * cy - ey) + dy_lbl)
    cairo_show_text(cr, remain_str)
  end

  ------------------------------------------------------------
  -- Vertical bars (idle-only): animate only in idle state
  ------------------------------------------------------------
  do
    -- Only draw idle bars if:
    -- 1) Widget is allowed to show while inactive (hide_when_inactive == false)
    -- 2) Player is NOT Playing or Paused
    local hide_cfg = THEME and THEME.music and THEME.music.hide_when_inactive
    if hide_cfg == false then
      local st = ""
      local f = io.popen("playerctl status 2>/dev/null")
      if f then
        st = f:read("*l") or ""; f:close()
      end
      if not (st == "Playing" or st == "Paused") then
        -- Theme toggle to enable/disable the idle animation
        local anim_flag = tget(THEME, "music.bars.animate_idle")
        if anim_flag ~= false then
          -- Geometry: span exactly between arc endpoints (same as your arc)
          local sx          = cx + r * math.cos(deg2rad(ARC_START))
          local ex          = cx + r * math.cos(deg2rad(ARC_END))
          local left, right = math.min(sx, ex), math.max(sx, ex)
          local span        = right - left

          -- Theme knobs
          local nbars       = tonumber(tget(THEME, "music.bars.count")) or 24
          local bar_w       = tonumber(tget(THEME, "music.bars.width")) or 6
          local max_h       = tonumber(tget(THEME, "music.bars.max_height")) or 48
          local lift_px     = tonumber(tget(THEME, "music.bars.lift_px")) or 12
          local color_hex   = tgetd("music.bars.color", tgetd("music.arc.progress_color", "FFFF00"))
          local alpha       = tonumber(tget(THEME, "music.bars.alpha")) or 1.0
          local speed_u     = tonumber(tget(THEME, "music.bars.speed_px_u")) or 2
          local wiggle_mult = tonumber(tget(THEME, "music.bars.wiggle_mult")) or 0.6

          -- Spacing so bars fill the span neatly
          local total_bar_w = nbars * bar_w
          local gap         = (nbars > 1) and (span - total_bar_w) / (nbars - 1) or 0
          if gap < 1 then gap = 1 end

          -- Baseline just above your horizontal line
          local base_y     = cy - lift_px

          -- Idle animation (phase per bar; tied to ${updates})
          local updates    = tonumber(conky_parse("${updates}")) or 0
          local phase_step = math.pi * 2 / math.max(nbars, 1)

          set_rgba_hex(cr, color_hex, alpha)
          for i = 0, nbars - 1 do
            local x = left + i * (bar_w + gap)
            local phase = i * phase_step + updates * (speed_u * 0.05)
            local val01 = (0.5 + 0.5 * math.sin(phase)) ^ 1.2 * wiggle_mult
            local h = math.max(1, max_h * val01)
            cairo_rectangle(cr, x, base_y - h, bar_w, h)
            cairo_fill(cr)
          end
        end
      end
    end
  end





  ------------------------------------------------------------
  -- Titles & Album (per-line controls; no shared fallbacks)
  ------------------------------------------------------------
  do
    local function draw_line_with_marquee(txt, cfg, cx, cy)
      if not txt or txt == "" then return end

      -- --- required per-line controls (with small hard defaults)
      local pt         = tonumber(cfg.pt) or 12
      local col        = cfg.color or "FFFFFF"
      local dy         = tonumber(cfg.dy) or 0
      local dx         = tonumber(cfg.dx) or 0
      local field_w    = tonumber(cfg.field_w) or 320
      local field_x    = tonumber(cfg.field_x) or (cx - math.floor(field_w / 2))

      -- --- per-line marquee controls
      local mq         = cfg.marquee or {}
      local gap_px     = tonumber(mq.gap_px) or 40
      local safety_px  = tonumber(mq.safety_px) or 0 -- 0 => auto buffer
      local speed_px_u = tonumber(mq.speed_px_u) or 2

      -- width estimate scaled by point size (no cairo extents needed)
      local base_font  = tgetd("font", "DejaVu Sans Mono:size=10")
      local base_pt    = tonumber((base_font:match(":size=(%d+)"))) or 10
      local char_px    = tonumber(tget(THEME, "char_px")) or 7
      local w_est      = (#txt) * char_px * (pt / base_pt)

      -- set font & color per-line
      set_rgba_hex(cr, col, 1.0)
      cairo_select_font_face(cr, (tgetd("font", "DejaVu Sans Mono"):gsub(":size=%d+", "")), 0, 0)
      cairo_set_font_size(cr, pt)

      local y      = cy + dy
      local x_left = field_x + dx

      if w_est <= field_w then
        -- fits: center within field (stable)
        local x_center = field_x + math.floor(field_w / 2)
        local x = x_center - math.floor(w_est / 2)
        cairo_move_to(cr, x, y)
        cairo_show_text(cr, txt)
        return
      end

      -- marquee scroll (per-line speed/spacing)
      if safety_px == 0 then safety_px = math.ceil(w_est * 0.15) end
      local period  = w_est + gap_px + safety_px
      local updates = tonumber(conky_parse("${updates}")) or 0
      local offset  = (updates * speed_px_u) % period

      cairo_save(cr)
      cairo_rectangle(cr, field_x, y - (pt + 6), field_w, (pt * 2) + 12)
      cairo_clip(cr)

      local start_x = x_left - offset
      for k = -1, 1 do
        local xk = start_x + k * period
        cairo_move_to(cr, xk, y)
        cairo_show_text(cr, txt)
      end
      cairo_restore(cr)
    end

    -- ===== Title =====
    do
      local status_f = io.popen("playerctl status 2>/dev/null"); local st = status_f and (status_f:read("*l") or "") or
          ""; if status_f then status_f:close() end
      local show_msg = (THEME and THEME.music and THEME.music.hide_when_inactive == false) and
          (st ~= "Playing" and st ~= "Paused")
      local txt = (show_msg and (tgetd("music.inactive_message", "Play music, feel better."))) or
          (meta.title ~= "" and meta.title) or "00 - Title"

      local cfg = (tget(THEME, "music.text.title") or {})
      draw_line_with_marquee(txt, cfg, cx, cy)
    end

    -- ===== Album =====
    do
      local txt = (meta.album ~= "" and meta.album) or ""
      if txt ~= "" then
        local cfg = (tget(THEME, "music.text.album") or {})
        draw_line_with_marquee(txt, cfg, cx, cy)
      end
    end

    -- ===== Artist =====
    do
      local txt = (meta.artist ~= "" and meta.artist) or ""
      local cfg = (tget(THEME, "music.text.artist") or {})
      draw_line_with_marquee(txt, cfg, cx, cy)
    end
  end


  ------------------------------------------------------------
  -- Cleanup
  ------------------------------------------------------------
  cairo_new_path(cr)
  cairo_restore(cr)
  cairo_destroy(cr)
  cairo_surface_destroy(cs)
  return ""
end
