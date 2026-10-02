-- Gate: no dashboard callback and no background-task wakeup may reach Ethos's
-- per-callback instruction limit ("Max instructions count reached", 20000).
--
-- Run it from the repository root:
--     lua5.4 bin/perf/verify_instruction_budget.lua
--
-- Each measurement runs in its own interpreter process, because the suite's
-- modules cache themselves in package.loaded and every theme has to start
-- cold, as it does on the radio. The interpreter is the one running this file
-- (arg[-1]), or $LUA when set -- e.g. a wrapper around an embedded Lua.
--
-- Dashboard: every theme in widgets/dashboard.lua's THEME_DIRS, in all three
-- flight states, cold boot plus 400 connected ticks -- worst wakeup() and
-- worst paint(). Background task: boot, link up, steady CRSF with ELRS
-- frames, a 20-frame ELRS backlog, link down -- worst wakeup() per phase. See
-- instruction_harness.lua for what is counted and what the figures are not.

local LIMIT = 20000

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end
local DIR = scriptDir()
local ROOT = DIR .. "/../.."
local LUA = os.getenv("LUA") or (arg and arg[-1]) or "lua5.4"

local failures, checks = 0, 0
local function check(label, ok, detail)
  checks = checks + 1
  if ok then
    print(string.format("  ok    %s", label))
  else
    failures = failures + 1
    print(string.format("  FAIL  %s", label))
    if detail then print("        " .. tostring(detail)) end
  end
end

local function run(script, ...)
  local cmd = LUA .. ' "' .. DIR .. "/" .. script .. '"'
  for _, a in ipairs({...}) do cmd = cmd .. " " .. a end
  local pipe = assert(io.popen(cmd .. " 2>&1", "r"))
  local out = pipe:read("a")
  pipe:close()
  return out
end

local function themes()
  local f = assert(io.open(ROOT .. "/src/rfsuite/widgets/dashboard.lua", "r"))
  local src = f:read("a")
  f:close()
  local block = assert(src:match("local THEME_DIRS = (%b{})"), "THEME_DIRS not found")
  local list = {}
  for key in block:gmatch('%[?"?([%w%-_]+)"?%]?%s*=%s*"widgets/dashboard/themes/') do
    list[#list + 1] = key
  end
  table.sort(list)
  return list
end

print("Dashboard callbacks (limit " .. LIMIT .. "):")
local worst, worstAt = 0, ""
for _, theme in ipairs(themes()) do
  for _, state in ipairs({"preflight", "inflight", "postflight"}) do
    local out = run("measure_dashboard_instructions.lua", theme, state)
    local line = out:match("RESULT[^\n]*")
    local label = theme .. " " .. state
    if not line then
      check(label .. " ran", false, out:sub(1, 400))
    else
      local errorLine = out:match("ERROR:[^\n]*")
      local peak = 0
      for _, key in ipairs({"coldWakeMax", "coldPaintMax", "wakeMax", "paintMax"}) do
        local v = tonumber(line:match(key .. "=(%d+)"))
        if v and v > peak then peak = v end
      end
      if peak > worst then worst, worstAt = peak, label end
      check(string.format("%-22s peak %5d", label, peak), peak < LIMIT and not errorLine,
        errorLine or line)
    end
  end
end
print(string.format("  worst dashboard callback: %d (%s)", worst, worstAt))

print("Background task wakeup (limit " .. LIMIT .. "):")
local out = run("measure_bg_instructions.lua")
local phases = 0
for name, peak in out:gmatch("\n  (%S[^\n]-)%s+max=%s*(%d+)@") do
  phases = phases + 1
  peak = tonumber(peak)
  check(string.format("%-40s peak %5d", name, peak), peak < LIMIT)
end
check("background task phases were measured", phases > 0, out:sub(1, 400))
local errorLine = out:match("ERROR:[^\n]*")
check("background task ran without errors", not errorLine, errorLine)

print(string.format("\n%d checks, %d failed", checks, failures))
os.exit(failures == 0 and 0 or 1)
