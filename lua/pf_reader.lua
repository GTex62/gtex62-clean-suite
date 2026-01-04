-- ~/.config/conky/gtex62-clean-suite/lua/pf_reader.lua
-- Minimal reader: runs pf-fetch-basic.sh, parses sections, prints a short summary.

local HOME = os.getenv("HOME") or ""
local FETCH = HOME .. "/.config/conky/gtex62-clean-suite/scripts/pf-fetch-basic.sh"

local function sh(cmd)
  local f = io.popen(cmd .. " 2>/dev/null")
  if not f then return "" end
  local out = f:read("*a") or ""
  f:close()
  return out
end

-- Parse key=value lines grouped by "section=<name>"
local function parse_kv(text)
  local out, cur = {}, nil
  for line in text:gmatch("[^\r\n]+") do
    local sec = line:match("^section=(%S+)")
    if sec then
      cur = sec
      out[cur] = out[cur] or {}
    else
      local k, v = line:match("^([%w_]+)=(.*)$")
      if k and cur then
        out[cur][k] = v
      end
    end
  end
  return out
end

-- Run fetcher
local raw = sh(FETCH)
if raw == "" then
  print("pf_reader: no output from fetch script: " .. FETCH)
  os.exit(1)
end
local T = parse_kv(raw)

-- Helper to safely read a value
local function get(sec, key) return (T[sec] and T[sec][key]) or "" end

-- Print a compact summary (human check only)
print("--- pfSense data (reader sanity) ---")
print("uptime: " .. (get("system", "uptime")))
print(string.format("cpu: user=%s system=%s idle=%s",
  get("system", "cpu_user"), get("system", "cpu_system"), get("system", "cpu_idle")))
print(get("system", "mem_line"))
print(get("system", "swap_line"))
print(string.format("gateway: online=%s ip=%s",
  get("gateway", "gateway_online"), get("gateway", "gateway_ip")))

-- Show iface counters for your 5 labels (by ifname keys we emitted)
local ifs = { "igc1.40", "igc1.10", "igc1.20", "igc1.30", "igc0" }
for _, ifn in ipairs(ifs) do
  local i = get("interfaces", "iface_" .. ifn .. "_ibytes")
  local o = get("interfaces", "iface_" .. ifn .. "_obytes")
  if i ~= "" or o ~= "" then
    print(string.format("%-7s ibytes=%s obytes=%s", ifn, i, o))
  end
end

-- pfBlockerNG
print(string.format("pfBlockerNG: ip_total=%s dnsbl_total=%s",
  get("pfblockerng", "pfb_ip_total"), get("pfblockerng", "pfb_dnsbl_total")))
