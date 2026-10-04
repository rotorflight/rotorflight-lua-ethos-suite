-- Instruction counts for the dashboard widget's Ethos callbacks, per theme and
-- flight state. See instruction_harness.lua for what is counted and why.
--
-- Usage (run from anywhere; needs Lua 5.3+):
--     lua5.4 bin/perf/measure_dashboard_instructions.lua <theme> <state> [w h] [profileTick]
--   theme      : a widgets/dashboard/themes/<dir> name   (default "default")
--   state      : preflight | inflight | postflight        (default "preflight")
--   w, h       : window size                             (default 800 480)
--   profileTick: connected tick whose wakeup+paint to profile by function
--
-- Phases: 20 ticks not connected (radio boot), then 400 connected ticks of
-- wakeup+paint 50ms apart with a session.update every 0.5s. "steady" averages
-- skip the first 100 connected ticks.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end
local H = dofile(scriptDir() .. "/instruction_harness.lua")

local THEME = arg and arg[1] or "default"
local STATE = arg and arg[2] or "preflight"
H.window.w = tonumber(arg and arg[3]) or 800
H.window.h = tonumber(arg and arg[4]) or 480
local PROFILE_TICK = tonumber(arg and arg[5])

H.settings = {dashboard = {theme = "system/" .. THEME, use_same_theme = true,
  theme_preflight = "system/" .. THEME}}
H.watchPrint("budget exhausted")

-- Per-object attribution: wrap each dashboard object module's wakeup/paint.
local perObject = {}
local function objectStats(kind)
  local s = perObject[kind]
  if not s then
    s = {wakeMax = 0, paintMax = 0, wakeCalls = 0, paintCalls = 0, wakeSum = 0, paintSum = 0}
    perObject[kind] = s
  end
  return s
end
table.insert(H.chunkWrappers, function(path, chunk)
  local kind = type(path) == "string" and path:match("^widgets/dashboard/objects/(.+)%.lua$")
  if not kind then return chunk end
  return function(...)
    local render = chunk(...)
    if type(render) ~= "table" then return render end
    local s = objectStats(kind)
    local wake, paint = render.wakeup, render.paint
    if wake then
      render.wakeup = function(box)
        local d = H.measure(wake, box)
        s.wakeCalls, s.wakeSum = s.wakeCalls + 1, s.wakeSum + d
        if d > s.wakeMax then s.wakeMax = d end
      end
    end
    if paint then
      render.paint = function(x, y, w, h, box)
        local d = H.measure(paint, x, y, w, h, box)
        s.paintCalls, s.paintSum = s.paintCalls + 1, s.paintSum + d
        if d > s.paintMax then s.paintMax = d end
      end
    end
    return render
  end
end)

local requireModule = assert(loadfile("lib/require.lua"))()
local bus = requireModule("lib/bus.lua")
requireModule("widgets/dashboard.lua").init({})
local def = assert(H.registered.widgets[1], "dashboard did not register a widget")
local widget = def.create()
-- Force the flight state under test; the real tracker needs arming history.
widget.flightmode = {update = function() return STATE end, reset = H.noop}

local r = {coldWakeMax = 0, coldPaintMax = 0, wakeMax = 0, paintMax = 0, wakeAt = 0, paintAt = 0,
  publishMax = 0, wakeOver = 0, paintOver = 0, steadyWake = 0, steadyPaint = 0, steadyN = 0}

H.start()

for _ = 1, 20 do
  H.advance(0.05)
  local w = H.measure(def.wakeup, widget)
  local p = H.measure(def.paint, widget)
  if w > r.coldWakeMax then r.coldWakeMax = w end
  if p > r.coldPaintMax then r.coldPaintMax = p end
end

for i = 1, 400 do
  H.advance(0.05)
  if i % 10 == 1 then
    -- The widget's share of the background task's tick: its session.update
    -- handler runs synchronously inside tasks/session.lua's publish.
    local d = H.measure(bus.publish, "session.update", H.sessionSnapshot(STATE == "inflight"))
    if d > r.publishMax then r.publishMax = d end
  end
  H.setProfiling(i == PROFILE_TICK)
  local w = H.measure(def.wakeup, widget)
  local p = H.measure(def.paint, widget)
  H.setProfiling(false)
  if w > r.wakeMax then r.wakeMax, r.wakeAt = w, i end
  if p > r.paintMax then r.paintMax, r.paintAt = p, i end
  if w > H.LIMIT then r.wakeOver = r.wakeOver + 1 end
  if p > H.LIMIT then r.paintOver = r.paintOver + 1 end
  if i > 100 then
    r.steadyWake, r.steadyPaint, r.steadyN = r.steadyWake + w, r.steadyPaint + p, r.steadyN + 1
  end
end

H.stop()

H.print(string.format(
  "RESULT theme=%s state=%s size=%dx%d coldWakeMax=%d coldPaintMax=%d wakeMax=%d@%d paintMax=%d@%d "
    .. "steadyWakeAvg=%d steadyPaintAvg=%d wakeOver=%d paintOver=%d publishMax=%d budgetMsgs=%d",
  THEME, STATE, H.window.w, H.window.h, r.coldWakeMax, r.coldPaintMax, r.wakeMax, r.wakeAt,
  r.paintMax, r.paintAt, r.steadyWake // r.steadyN, r.steadyPaint // r.steadyN,
  r.wakeOver, r.paintOver, r.publishMax, H.watched("budget exhausted")))

print = H.print
H.printModuleLoads(6)
local kinds = {}
for k in pairs(perObject) do kinds[#kinds + 1] = k end
table.sort(kinds, function(a, b)
  return math.max(perObject[a].wakeMax, perObject[a].paintMax) > math.max(perObject[b].wakeMax, perObject[b].paintMax)
end)
for _, k in ipairs(kinds) do
  local s = perObject[k]
  print(string.format("  OBJ %-18s wakeMax=%6d wakeAvg=%6d paintMax=%6d paintAvg=%6d",
    k, s.wakeMax, s.wakeCalls > 0 and s.wakeSum // s.wakeCalls or 0,
    s.paintMax, s.paintCalls > 0 and s.paintSum // s.paintCalls or 0))
end
if PROFILE_TICK then H.printProfile("connected tick " .. PROFILE_TICK .. " (wakeup+paint)") end
