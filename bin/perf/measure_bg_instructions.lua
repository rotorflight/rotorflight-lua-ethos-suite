-- Instruction counts for the background task's wakeup (tasks/background.lua),
-- with the real main.lua loaded so every synchronous "session.update"
-- subscriber (tool, logging, audio, ELRS link tool, dashboard widgets) is
-- charged to the tick that publishes it, as on the radio. See
-- instruction_harness.lua for what is counted and why.
--
-- Usage (run from anywhere; needs Lua 5.3+):
--     lua5.4 bin/perf/measure_bg_instructions.lua [theme] [dashboards] [profileTick]
--   theme      : dashboard theme on screen          (default "kevd")
--   dashboards : dashboard widget instances         (default 1)
--   profileTick: tick whose task wakeup to profile by function
--
-- Phases (50ms ticks): boot with the link down (covers BOOT_DEFER_S and the
-- one-tick load burst), link up, a steady CRSF phase with ELRS custom
-- telemetry frames arriving every tick, one backlog burst of BURST_FRAMES
-- frames (the task was starved for ~1s), then link down.
--
-- Not modelled: MSP replies (the handshake's requests go unanswered and
-- retry), arming, the app tool open on a page (its pages add their own
-- session.update handlers).

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end
local H = dofile(scriptDir() .. "/instruction_harness.lua")

local THEME = arg and arg[1] or "kevd"
local DASHBOARDS = tonumber(arg and arg[2]) or 1
local PROFILE_TICK = tonumber(arg and arg[3])
local BURST_FRAMES = 20

H.settings = {dashboard = {theme = "system/" .. THEME, use_same_theme = true,
  theme_preflight = "system/" .. THEME}}
H.useCrsf()

-- ELRS custom telemetry frames as transport_crsf.lua's popFrame hands them to
-- tasks/elrs_sensors.lua: 2 address bytes + 1 frame-id byte, then
-- (SID:U16, value) pairs, up to a 58-byte CRSF payload.
local function u16(t, v) t[#t + 1] = (v >> 8) & 0xFF; t[#t + 1] = v & 0xFF end
local function frameOf(pairs_)
  local f = {0xEA, 0xC8, 0x00}
  for _, p in ipairs(pairs_) do
    u16(f, p[1])
    for _, b in ipairs(p[2]) do f[#f + 1] = b end
  end
  return f
end
local W = {0x01, 0x23}
local FRAME_DENSE = frameOf({   -- 13 plain U16 sensors, 55 bytes
  {0x1011, W}, {0x1012, W}, {0x1013, W}, {0x1041, W}, {0x1042, W}, {0x1043, W}, {0x1045, W},
  {0x1046, W}, {0x1049, W}, {0x1080, W}, {0x1081, W}, {0x10C0, W}, {0x1128, W},
})
local FRAME_AGGREGATE = frameOf({   -- the multi-value decoders, 50 bytes
  {0x102F, {6, 210, 211, 212, 213, 214, 215}},
  {0x1100, {0, 10, 0, 20, 0, 30}},
  {0x1110, {0, 1, 0, 2, 0, 3}},
  {0x1030, {1, 2, 3, 4, 5, 6}},
  {0x1125, {1, 2, 3, 4, 5, 6, 7, 8}},
  {0x1001, W},
})
local CUSTOM_TELEM = 0x88
local function queueFrames(n)
  local q = H.crsfQueues[CUSTOM_TELEM] or {}
  H.crsfQueues[CUSTOM_TELEM] = q
  for i = 1, n do
    local src = (i % 2 == 0) and FRAME_DENSE or FRAME_AGGREGATE
    local copy = {}
    for j = 1, #src do copy[j] = src[j] end
    q[#q + 1] = copy
  end
end

-- Boot exactly as Ethos does: run main.lua, then its init().
assert(loadfile("main.lua"))().init()
local task = assert(H.registered.tasks[1], "background task did not register")
local dash
for _, def in ipairs(H.registered.widgets) do
  if type(def.key) == "string" and def.key:match("sdh$") then dash = def end  -- wfsdh / rf2sdh
end
local widgets = {}
for i = 1, DASHBOARDS do widgets[i] = dash.create() end

local phases, order = {}, {}
local function phase(name)
  local p = phases[name]
  if not p then
    p = {max = 0, maxAt = 0, sum = 0, n = 0, over = 0}
    phases[name] = p
    order[#order + 1] = name
  end
  return p
end

H.linkUp = false
task.init()

local tick = 0
local function step(name, framesPerTick)
  tick = tick + 1
  H.advance(0.05)
  H.sensorValue = 12 + (tick % 10) * 0.1
  if framesPerTick and framesPerTick > 0 then queueFrames(framesPerTick) end
  H.setProfiling(tick == PROFILE_TICK)
  local d = H.measure(task.wakeup)
  H.setProfiling(false)
  local p = phase(name)
  p.n, p.sum = p.n + 1, p.sum + d
  if d > p.max then p.max, p.maxAt = d, tick end
  if d > H.LIMIT then p.over = p.over + 1 end
  -- The dashboards keep running between task ticks (uncounted here), so their
  -- subscriptions and theme state are live, as on the radio.
  for i = 1, #widgets do
    H.measure(dash.wakeup, widgets[i])
    H.measure(dash.paint, widgets[i])
  end
end

H.start()
for _ = 1, 60 do step("boot (link down, defer + load burst)") end
H.linkUp = true
step("link up edge")
for _ = 1, 40 do step("connected, first 2s") end
for _ = 1, 400 do step("steady, 1 ELRS frame/tick", 1) end
queueFrames(BURST_FRAMES)
step(string.format("ELRS backlog burst (%d frames)", BURST_FRAMES))
for _ = 1, 40 do step("steady after burst", 1) end
H.linkUp = false
step("link down edge")
for _ = 1, 20 do step("link down") end
H.stop()

print = H.print
print(string.format("RESULT bg theme=%s dashboards=%d", THEME, DASHBOARDS))
for _, name in ipairs(order) do
  local p = phases[name]
  print(string.format("  %-40s max=%6d@%-4d avg=%6d over=%d", name, p.max, p.maxAt, p.sum // p.n, p.over))
end
if PROFILE_TICK then H.printProfile("task wakeup, tick " .. PROFILE_TICK) end
