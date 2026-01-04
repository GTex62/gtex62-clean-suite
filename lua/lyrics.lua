---@diagnostic disable: undefined-global, cast-local-type, assign-type-mismatch, need-check-nil, param-type-mismatch

-- ~/.config/conky/gtex62-clean-suite/lua/lyrics.lua
-- Lyrics panel (v1 skeleton)
-- • Uses theme.lua for layout/colors (theme.lyrics).
-- • Provides:
--     ${lua_parse lyrics_visible}  -> "0" or "1"
--     ${lua lyrics_draw}          -> draws header + placeholder text
-- • v1: NO fetching yet. We'll wire providers/cache later.

--------------------------
-- Cairo availability
--------------------------
local has_cairo = pcall(require, "cairo") -- enables global cairo_* funcs in Conky

--------------------------
-- THEME loader (same pattern as music.lua)
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
local function set_rgba_hex(cr, hex, a)
  hex = (hex or "FFFFFF"):gsub("#", "")
  local r = tonumber(hex:sub(1, 2), 16) or 255
  local g = tonumber(hex:sub(3, 4), 16) or 255
  local b = tonumber(hex:sub(5, 6), 16) or 255
  cairo_set_source_rgba(cr, r / 255, g / 255, b / 255, a or 1)
end

local function read_cmd(cmd)
  local f = io.popen(cmd .. " 2>/dev/null"); if not f then return nil end
  local out = f:read("*a"); f:close()
  if not out or out == "" then return nil end
  return (out:gsub("%s+$", ""))
end

local function get_player_status()
  local st = read_cmd("playerctl status 2>/dev/null") or ""
  return st
end

local function get_player_meta()
  local artist = read_cmd("playerctl metadata xesam:artist 2>/dev/null") or ""
  local title  = read_cmd("playerctl metadata xesam:title  2>/dev/null") or ""
  local album  = read_cmd("playerctl metadata xesam:album  2>/dev/null") or ""
  return { artist = artist, title = title, album = album }
end

local function fmt_header(cfg, meta)
  local fmt = cfg.format or "{artist} — {title}"
  local s = fmt
  s = s:gsub("{artist}", meta.artist or "")
  s = s:gsub("{title}", meta.title or "")
  s = s:gsub("{album}", meta.album or "")
  -- cleanup: collapse extra separators if missing fields
  s = s:gsub("%s+$", ""):gsub("^%s+", "")
  return s
end

local function sanitize_key(s)
  s = tostring(s or ""):lower()
  s = s:gsub("[/%\\:%*%?%\"%<%>%|]", " ")
  s = s:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
  return s
end

local function shell_quote(s)
  s = tostring(s or "")
  return "'" .. s:gsub("'", "'\\''") .. "'"
end

local function url_encode(s)
  s = tostring(s or ""):gsub("\n", " ")
  return (s:gsub("([^%w%-%._~])", function(c)
    return string.format("%%%02X", string.byte(c))
  end))
end

local function load_lyrics_vars()
  local path = HOME .. "/.config/conky/gtex62-clean-suite/widgets/lyrics.vars"
  local f = io.open(path, "r")
  if not f then return {} end
  local vars = {}
  for line in f:lines() do
    if not line:match("^%s*$") and not line:match("^%s*#") then
      local key, val = line:match("^%s*([%w_]+)%s*=%s*(.-)%s*$")
      if key then
        val = val:gsub('^"(.*)"$', "%1"):gsub("^'(.*)'$", "%1")
        vars[key] = val
      end
    end
  end
  f:close()
  return vars
end

local function is_online_enabled()
  local vars = load_lyrics_vars()
  local v = vars.LYRICS_ENABLE_ONLINE
  if v == nil or v == "" then return true end
  return tostring(v) ~= "0"
end

local function get_local_dirs()
  local vars = load_lyrics_vars()
  local list = vars.LYRICS_LOCAL_DIRS or ""
  local dirs = {}
  for part in tostring(list):gmatch("[^,]+") do
    local dir = part:gsub("^%s+", ""):gsub("%s+$", "")
    if dir ~= "" then
      dir = dir:gsub("^%$HOME", HOME):gsub("^~", HOME)
      table.insert(dirs, dir)
    end
  end
  if #dirs == 0 then
    dirs = { HOME .. "/Music/lyrics" }
  end
  return dirs
end

local function get_cache_dir()
  local vars = load_lyrics_vars()
  local dir = vars.LYRICS_CACHE_DIR or ""
  dir = tostring(dir):gsub("^%s+", ""):gsub("%s+$", "")
  if dir ~= "" then
    dir = dir:gsub("^%$HOME", HOME):gsub("^~", HOME)
    return dir
  end
  return HOME .. "/.cache/conky/lyrics"
end

local function get_noapi_providers()
  local vars = load_lyrics_vars()
  local list = vars.LYRICS_PROVIDERS_NOAPI or "lrclib,lyrics_ovh"
  if list == "" then
    list = "lrclib,lyrics_ovh"
  end
  local providers = {}
  for part in tostring(list):gmatch("[^,]+") do
    local name = part:gsub("^%s+", ""):gsub("%s+$", ""):lower()
    if name ~= "" then
      table.insert(providers, name)
    end
  end
  return providers
end

local function json_get_string(json, field)
  if not json or json == "" then return nil end
  local pattern = '"' .. field .. '"%s*:%s*"(.-)"'
  local val = json:match(pattern)
  if not val then return nil end
  val = val:gsub("\\n", "\n")
  val = val:gsub("\\r", "\r")
  val = val:gsub("\\t", "\t")
  val = val:gsub('\\"', '"')
  val = val:gsub("\\\\", "\\")
  return val
end

local function normalize_lyrics_text(s)
  if not s or s == "" then return s end
  s = s:gsub("\\\\n", "\n")
  s = s:gsub("\\n", "\n")
  s = s:gsub("\r\n", "\n"):gsub("\r", "\n")
  s = s:gsub("<%s*[Bb][Rr]%s*/?>", "\n")
  s = s:gsub("[ \t]+(\n)", "%1")
  s = s:gsub("[ \t]+$", "")
  if tgetd("lyrics.normalize_blank_lines", false) then
    local max_run = tonumber(tgetd("lyrics.max_blank_run", 1)) or 1
    if max_run < 0 then max_run = 0 end
    local whitespace_blank = (tgetd("lyrics.whitespace_only_is_blank", true) ~= false)
    local out = {}
    local blank_run = 0
    for line in (s .. "\n"):gmatch("(.-)\n") do
      local is_blank = whitespace_blank and line:match("^%s*$") or line == ""
      if is_blank then
        blank_run = blank_run + 1
        if max_run > 0 and blank_run <= max_run then
          table.insert(out, "")
        end
      else
        blank_run = 0
        table.insert(out, line)
      end
    end
    s = table.concat(out, "\n")
  end
  if not s:match("\n$") then
    s = s .. "\n"
  end
  return s
end

local function strip_lrc_prefix(line)
  if not tgetd("lyrics.strip_lrc_timestamps", false) then return line end
  local out = line or ""
  while out:match("^%[%d+:%d+%.?%d*%]") do
    out = out:gsub("^%[%d+:%d+%.?%d*%]", "", 1)
  end
  if out:sub(1, 1) == " " then
    out = out:sub(2)
  end
  return out
end

local function is_lrc_text(s)
  if not s or s == "" then return false end
  return s:match("%[%d+:%d+%.?%d*%]") ~= nil
end

local function ensure_dir(path)
  os.execute("mkdir -p " .. shell_quote(path) .. " >/dev/null 2>&1")
end

local function is_offline()
  local ok_ip = read_cmd("getent hosts 1.1.1.1 >/dev/null 2>&1; echo $?")
  local ok_host = read_cmd("getent hosts lyrics.ovh >/dev/null 2>&1; echo $?")
  if ok_ip ~= "0" or ok_host ~= "0" then
    return true
  end
  return false
end

local function read_lines(path, max_bytes)
  local f = io.open(path, "r")
  if not f then return nil end
  local bytes = tonumber(max_bytes) or 200000
  local data = f:read(bytes) or ""
  f:close()
  local lines = {}
  for line in (data .. "\n"):gmatch("(.-)\n") do
    line = line:gsub("\r$", "")
    table.insert(lines, line)
  end
  if tgetd("lyrics.normalize_blank_lines", false) then
    local max_run = tonumber(tgetd("lyrics.max_blank_run", 1)) or 1
    if max_run < 0 then max_run = 0 end
    local whitespace_blank = (tgetd("lyrics.whitespace_only_is_blank", true) ~= false)
    local out = {}
    local blank_run = 0
    for _, line in ipairs(lines) do
      local is_blank = whitespace_blank and line:match("^%s*$") or line == ""
      if is_blank then
        blank_run = blank_run + 1
        if max_run > 0 and blank_run <= max_run then
          table.insert(out, "")
        end
      else
        blank_run = 0
        table.insert(out, line)
      end
    end
    lines = out
  end
  return lines
end

local function track_key(meta)
  local artist = meta and meta.artist or ""
  local title = meta and meta.title or ""
  if artist == "" or title == "" then return "" end
  return sanitize_key(artist) .. " - " .. sanitize_key(title)
end

local function find_local_lyrics(meta, cfg)
  local artist = meta and meta.artist or ""
  local title = meta and meta.title or ""
  if artist == "" or title == "" then return nil end
  local stem = artist .. " - " .. title
  local safe_stem = sanitize_key(artist) .. " - " .. sanitize_key(title)
  local dirs = get_local_dirs()
  for _, dir in ipairs(dirs) do
    local paths = {
      dir .. "/" .. stem .. ".lrc",
      dir .. "/" .. stem .. ".txt",
      dir .. "/" .. safe_stem .. ".lrc",
      dir .. "/" .. safe_stem .. ".txt",
      dir .. "/lyrics.txt",
    }
    for _, path in ipairs(paths) do
      local f = io.open(path, "r")
      if f then
        f:close()
        return path
      end
    end
  end
  return nil
end

local function find_cached_lyrics(meta)
  local artist = meta and meta.artist or ""
  local title = meta and meta.title or ""
  if artist == "" or title == "" then return nil end
  local stem = artist .. " - " .. title
  local safe_stem = sanitize_key(artist) .. " - " .. sanitize_key(title)
  local dir = get_cache_dir()
  local paths = {
    dir .. "/" .. stem .. ".lrc",
    dir .. "/" .. stem .. ".txt",
    dir .. "/" .. safe_stem .. ".lrc",
    dir .. "/" .. safe_stem .. ".txt",
  }
  for _, path in ipairs(paths) do
    local f = io.open(path, "r")
    if f then
      f:close()
      return path
    end
  end
  return nil
end

local function fetch_lyrics_ovh(artist, title)
  local url = "https://api.lyrics.ovh/v1/" .. url_encode(artist) .. "/" .. url_encode(title)
  local json = read_cmd("curl -fsSL --max-time 8 " .. shell_quote(url))
  if not json or json == "" then return nil end
  local text = json_get_string(json, "lyrics")
  return normalize_lyrics_text(text)
end

local function fetch_lrclib(artist, title)
  local url = "https://lrclib.net/api/get?artist_name=" .. url_encode(artist) .. "&track_name=" .. url_encode(title)
  local json = read_cmd("curl -fsSL --max-time 8 " .. shell_quote(url))
  if not json or json == "" then return nil end
  local synced = normalize_lyrics_text(json_get_string(json, "syncedLyrics"))
  if synced and synced ~= "" then
    return synced, "lrc"
  end
  local plain = normalize_lyrics_text(json_get_string(json, "plainLyrics") or json_get_string(json, "lyrics"))
  if plain and plain ~= "" then
    return plain, "txt"
  end
  return nil
end

local function save_cached_lyrics(meta, text, ext)
  local artist = meta and meta.artist or ""
  local title = meta and meta.title or ""
  if artist == "" or title == "" then return nil end
  local dir = get_cache_dir()
  ensure_dir(dir)
  local stem = artist .. " - " .. title
  local safe_stem = sanitize_key(artist) .. " - " .. sanitize_key(title)
  local path = dir .. "/" .. stem .. "." .. ext
  local f = io.open(path, "w")
  if not f then
    path = dir .. "/" .. safe_stem .. "." .. ext
    f = io.open(path, "w")
  end
  if not f then return nil end
  f:write(text)
  f:close()
  return path
end

local FETCH_THROTTLE_S = 30
local MISS_RETRY_S = 12 * 60 * 60
local LYRICS_FETCH_STATE = {
  last_track_key = "",
  last_fetch_time = 0,
  last_result = "",
  last_saved_track_key = "",
  last_saved_path = "",
}

local function update_track_state(key)
  if key ~= LYRICS_FETCH_STATE.last_track_key then
    LYRICS_FETCH_STATE.last_track_key = key
    LYRICS_FETCH_STATE.last_fetch_time = 0
    LYRICS_FETCH_STATE.last_result = ""
    LYRICS_FETCH_STATE.last_saved_track_key = ""
    LYRICS_FETCH_STATE.last_saved_path = ""
  end
end

local function fetch_online_lyrics(meta, key)
  local now = os.time()
  if key == "" then
    return nil, "miss"
  end
  if key == LYRICS_FETCH_STATE.last_track_key then
    if LYRICS_FETCH_STATE.last_result == "miss" and (now - LYRICS_FETCH_STATE.last_fetch_time) < MISS_RETRY_S then
      return nil, "miss"
    end
    if (now - LYRICS_FETCH_STATE.last_fetch_time) < FETCH_THROTTLE_S then
      return nil, "throttled"
    end
  end
  LYRICS_FETCH_STATE.last_fetch_time = now

  local artist = meta and meta.artist or ""
  local title = meta and meta.title or ""
  local providers = get_noapi_providers()
  for _, name in ipairs(providers) do
    local text, forced_ext
    if name == "lyrics_ovh" then
      text = fetch_lyrics_ovh(artist, title)
    elseif name == "lrclib" then
      text, forced_ext = fetch_lrclib(artist, title)
    end
    if text and text ~= "" then
      local instrumental = text:match("^%s*[Ii]nstrumental%s*$")
      if instrumental then
        LYRICS_FETCH_STATE.last_result = "instrumental"
        return nil, "instrumental"
      end
      local ext = forced_ext or (is_lrc_text(text) and "lrc" or "txt")
      local path = save_cached_lyrics(meta, text, ext)
      if path then
        LYRICS_FETCH_STATE.last_result = "hit"
        LYRICS_FETCH_STATE.last_saved_track_key = key
        LYRICS_FETCH_STATE.last_saved_path = path
        return path, "hit"
      end
    end
  end
  LYRICS_FETCH_STATE.last_result = "miss"
  return nil, "miss"
end

------------------------------------------------------------
-- Visibility helper with theme toggle (own timer, like music.lua)
-- • If hide_when_inactive == false → always visible
-- • If true → visible while Playing/Paused; hide N seconds after stopped
------------------------------------------------------------
local LYRICS_LAST_SEEN = os.time()

function conky_lyrics_visible()
  local cfg = (THEME and THEME.lyrics) or {}
  if cfg.enabled == false then
    return "0"
  end

  if cfg.hide_when_inactive == false then
    return "1"
  end

  local now = os.time()
  local status = get_player_status()

  if status == "Playing" or status == "Paused" then
    LYRICS_LAST_SEEN = now
    return "1"
  end

  local threshold = tonumber(cfg.idle_hide_after_s) or 10
  if (now - LYRICS_LAST_SEEN) < threshold then
    return "1"
  end

  return "0"
end

--------------------------
-- Main draw (skeleton)
--------------------------
function conky_lyrics_draw()
  if not has_cairo or not conky_window then return "" end

  local cfg = (THEME and THEME.lyrics) or {}

  -- Cairo surface/context
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

  -- Basic typography
  local font_base = (tgetd("font", "DejaVu Sans Mono:size=10"):gsub(":size=%d+", ""))

  -- Padding + layout
  local pad       = cfg.padding or {}
  local pxL       = tonumber(pad.left) or 10
  local pxT       = tonumber(pad.top) or 10

  local status    = get_player_status()
  local meta      = get_player_meta()
  local key       = track_key(meta)
  update_track_state(key)

  local x          = pxL
  local y          = pxT

  --------------------------
  -- Header
  --------------------------
  local header_cfg = cfg.header or {}
  local header_on  = (header_cfg.enabled ~= false)
  if status ~= "Playing" and status ~= "Paused" then
    header_on = false
  end

  if header_on then
    local header_txt = fmt_header(header_cfg, meta)
    local header_pt  = tonumber(header_cfg.pt) or 12
    local header_col = header_cfg.color or "FFFFFF"

    -- If nothing playing, show placeholder header too (optional),
    -- but keep it simple for v1.
    if header_txt == "" then
      if status == "Playing" or status == "Paused" then
        header_txt = "—"
      else
        header_on = false
      end
    end

    if header_on then
      set_rgba_hex(cr, header_col, 1.0)
      cairo_select_font_face(cr, font_base, 0, (header_cfg.bold and 1 or 0))
      cairo_set_font_size(cr, header_pt)

      cairo_move_to(cr, x, y + header_pt)
      cairo_show_text(cr, header_txt)

      -- advance cursor
      y = y + header_pt + 8
    end
  end

  --------------------------
  -- Body (placeholder for now)
  --------------------------
  local body_cfg     = cfg.body or {}
  local body_pt      = tonumber(body_cfg.pt) or 11
  local body_col     = body_cfg.color or "FFFFFF"
  local line_px      = tonumber(body_cfg.line_px) or (body_pt + 3)
  local pxB          = tonumber(pad.bottom) or 10
  local box_h        = conky_window.height
  local avail_h_base = box_h - (y + pxB)

  set_rgba_hex(cr, body_col, 1.0)
  cairo_select_font_face(cr, font_base, 0, 0)
  cairo_set_font_size(cr, body_pt)

  if cfg.hide_when_inactive == false and not (status == "Playing" or status == "Paused") then
    local body_txt = cfg.inactive_message or "Lyrics can make the song, don't you think?"
    cairo_move_to(cr, x, y + body_pt)
    cairo_show_text(cr, body_txt)
  else
    local show_footer = (cfg.show_saved_path == true)
        and (LYRICS_FETCH_STATE.last_saved_track_key == key)
        and (LYRICS_FETCH_STATE.last_saved_path ~= "")
    local path = find_local_lyrics(meta, cfg) or find_cached_lyrics(meta)
    if not path then
      if is_online_enabled() then
        if is_offline() then
          LYRICS_FETCH_STATE.last_result = "offline"
          local body_txt = cfg.offline_message or "Offline"
          cairo_move_to(cr, x, y + body_pt)
          cairo_show_text(cr, body_txt)
        else
          local fetched_path, result = fetch_online_lyrics(meta, key)
          if result == "instrumental" then
            local body_txt = cfg.instrumental_message or "Instrumental"
            cairo_move_to(cr, x, y + body_pt)
            cairo_show_text(cr, body_txt)
          elseif result == "throttled" then
            local body_txt = "Searching…"
            cairo_move_to(cr, x, y + body_pt)
            cairo_show_text(cr, body_txt)
          else
            path = fetched_path or LYRICS_FETCH_STATE.last_saved_path
            if path then
              local footer_pt = math.max(9, body_pt - 1)
              local footer_line_px = tonumber(body_cfg.line_px) or (footer_pt + 3)
              local avail_h = avail_h_base - (show_footer and footer_line_px or 0)
              local max_lines = math.max(1, math.floor(avail_h / line_px))

              local lines = read_lines(path) or {}
              local total = #lines
              local show_lines = math.min(total, max_lines)
              if total > max_lines then
                lines[show_lines] = cfg.more_marker or "…more…"
              end
              for i = 1, show_lines do
                local line = strip_lrc_prefix(lines[i] or "")
                cairo_move_to(cr, x, y + body_pt + (i - 1) * line_px)
                cairo_show_text(cr, line)
              end

              if show_footer then
                local footer_txt = (cfg.saved_prefix or "Saved to: ") .. LYRICS_FETCH_STATE.last_saved_path
                local footer_y = y + (avail_h_base - footer_line_px) + footer_pt
                set_rgba_hex(cr, body_col, 0.75)
                cairo_select_font_face(cr, font_base, 0, 0)
                cairo_set_font_size(cr, footer_pt)
                cairo_move_to(cr, x, footer_y)
                cairo_show_text(cr, footer_txt)
              end
            else
              path = find_cached_lyrics(meta)
            end
            if not path then
              local body_txt = cfg.not_found_message or "Lyrics not found"
              cairo_move_to(cr, x, y + body_pt)
              cairo_show_text(cr, body_txt)
            end
          end
        end
      else
        local body_txt = cfg.not_found_message or "Lyrics not found"
        cairo_move_to(cr, x, y + body_pt)
        cairo_show_text(cr, body_txt)
      end
    else
      local footer_pt = math.max(9, body_pt - 1)
      local footer_line_px = tonumber(body_cfg.line_px) or (footer_pt + 3)
      local avail_h = avail_h_base - (show_footer and footer_line_px or 0)
      local max_lines = math.max(1, math.floor(avail_h / line_px))

      local lines = read_lines(path) or {}
      local total = #lines
      local show_lines = math.min(total, max_lines)
      if total > max_lines then
        lines[show_lines] = cfg.more_marker or "…more…"
      end
      for i = 1, show_lines do
        local line = strip_lrc_prefix(lines[i] or "")
        cairo_move_to(cr, x, y + body_pt + (i - 1) * line_px)
        cairo_show_text(cr, line)
      end

      if show_footer then
        local footer_txt = (cfg.saved_prefix or "Saved to: ") .. LYRICS_FETCH_STATE.last_saved_path
        local footer_y = y + (avail_h_base - footer_line_px) + footer_pt
        set_rgba_hex(cr, body_col, 0.75)
        cairo_select_font_face(cr, font_base, 0, 0)
        cairo_set_font_size(cr, footer_pt)
        cairo_move_to(cr, x, footer_y)
        cairo_show_text(cr, footer_txt)
      end
    end
  end

  --------------------------
  -- Cleanup
  --------------------------
  cairo_new_path(cr)
  cairo_restore(cr)
  cairo_destroy(cr)
  cairo_surface_destroy(cs)
  return ""
end
