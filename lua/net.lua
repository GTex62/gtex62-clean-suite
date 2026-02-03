---@diagnostic disable: lowercase-global
-- ${CONKY_SUITE_DIR:-~/.config/conky/gtex62-clean-suite}/scripts/net.lua

local HOME = os.getenv("HOME") or ""
local XDG_CACHE_HOME = os.getenv("XDG_CACHE_HOME") or (HOME .. "/.cache")
local CACHE_DIR = os.getenv("CONKY_CACHE_DIR") or (XDG_CACHE_HOME .. "/conky")
local iface_path = CACHE_DIR .. "/iface"

local function read_iface()
  local f = io.open(iface_path, "r")
  if not f then return "" end
  local s = f:read("*l") or ""
  f:close()
  -- trim whitespace
  return (s:gsub("%s+", ""))
end

function conky_net_iface()
  return read_iface()
end

function conky_net_addr()
  local i = read_iface()
  if i == "" then return "—" end
  return conky_parse("${addr " .. i .. "}")
end

function conky_net_downspeedf()
  local i = read_iface()
  if i == "" then return "0" end
  return conky_parse("${downspeedf " .. i .. "}")
end

function conky_net_upspeedf()
  local i = read_iface()
  if i == "" then return "0" end
  return conky_parse("${upspeedf " .. i .. "}")
end

function conky_net_downgraph()
  local i = read_iface()
  if i == "" then return "" end
  return conky_parse("${downspeedgraph " .. i .. " 20,145}")
end

function conky_net_upgraph()
  local i = read_iface()
  if i == "" then return "" end
  return conky_parse("${upspeedgraph " .. i .. " 20,145}")
end
