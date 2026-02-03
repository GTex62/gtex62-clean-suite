#!/usr/bin/env lua

-- Read placement from theme.lua
local HOME     = os.getenv("HOME") or ""
local SUITE_DIR = os.getenv("CONKY_SUITE_DIR") or (HOME .. "/.config/conky/gtex62-clean-suite")
local XDG_CACHE_HOME = os.getenv("XDG_CACHE_HOME") or (HOME .. "/.cache")
local CACHE_DIR = os.getenv("CONKY_CACHE_DIR") or (XDG_CACHE_HOME .. "/conky")
local THEME_PATH = os.getenv("CONKY_THEME_PATH") or (SUITE_DIR .. "/theme.lua")
local THEME    = dofile(THEME_PATH)
local ART      = (THEME.music and THEME.music.art) or nil
local FIXED    = (THEME.music and THEME.music.art_fixed) or {}

local function tget(root, dotted)
  local node = root
  for key in string.gmatch(dotted or "", "[^%.]+") do
    if type(node) ~= "table" then return nil end
    node = node[key]
  end
  return node
end

local function get_arc_anchor()
  local cx = tonumber(tget(THEME, "music.center.x")) or 0
  local cy = tonumber(tget(THEME, "music.center.y")) or 0
  return cx, cy
end

local X, Y, W, H
if ART and ART.dx ~= nil and ART.dy ~= nil and ART.w ~= nil and ART.h ~= nil then
  local cx, cy = get_arc_anchor()
  local dx = tonumber(ART.dx)
  local dy = tonumber(ART.dy)
  W = tonumber(ART.w)
  H = tonumber(ART.h)
  X = math.floor(cx + dx - (W / 2))
  Y = math.floor(cy + dy - (H / 2))
else
  -- Fallback to your proven values if theme is missing
  X = tonumber(FIXED.x) or 252
  Y = tonumber(FIXED.y) or 160
  W = tonumber(FIXED.w) or 62
  H = tonumber(FIXED.h) or 60
end

-- Cache + fallback art
local CACHE    = CACHE_DIR .. "/nowplaying_cover.png"
local FALLBACK = SUITE_DIR .. "/icons/horn-of-odin.png"
local TMPDIR   = CACHE_DIR .. "/cover_dyn"

local function file_exists(p)
  local f = io.open(p, "rb"); if f then
    f:close(); return true
  end; return false
end
local function shell_read(cmd)
  local f = io.popen(cmd); if not f then return nil end
  local out = f:read("*a"); f:close()
  return out and out:gsub("%s+$", "") or nil
end
local function mtime(path)
  local out = shell_read('stat -c %Y ' .. string.format("%q", path) .. ' 2>/dev/null')
  return tonumber(out or "0") or 0
end

-- Ensure temp dir & prune old copies
os.execute('mkdir -p ' .. string.format("%q", TMPDIR))
os.execute('find ' .. string.format("%q", TMPDIR) .. ' -type f -name "cover_*.png" -mmin +30 -delete 2>/dev/null')

-- Copy to mtime-named file to force Conky reload
local imgpath
if file_exists(CACHE) then
  local mt = mtime(CACHE)
  local out = string.format("%s/cover_%d.png", TMPDIR, mt)
  if not file_exists(out) then
    local src = io.open(CACHE, "rb")
    if src then
      local data = src:read("*a"); src:close()
      local dst = io.open(out, "wb")
      if dst then
        dst:write(data); dst:close()
      end
    end
  end
  imgpath = out
else
  imgpath = FALLBACK
end

-- Emit a real Conky image directive each update
io.write(string.format("${image %s -p %d,%d -s %dx%d}", imgpath, X, Y, W, H))
