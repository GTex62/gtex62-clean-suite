#!/usr/bin/env lua

-- Read placement from theme.lua
local HOME     = os.getenv("HOME") or ""
local THEME    = dofile(HOME .. "/.config/conky/gtex62-clean-suite/theme.lua")
local FIXED    = (THEME.music and THEME.music.art_fixed) or {}

-- Fallback to your proven values if theme is missing
local X        = tonumber(FIXED.x) or 252
local Y        = tonumber(FIXED.y) or 160
local W        = tonumber(FIXED.w) or 62
local H        = tonumber(FIXED.h) or 60

-- Cache + fallback art
local CACHE    = HOME .. "/.cache/conky/nowplaying_cover.png"
local FALLBACK = HOME .. "/.config/conky/gtex62-clean-suite/icons/horn-of-odin.png"
local TMPDIR   = HOME .. "/.cache/conky/cover_dyn"

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
