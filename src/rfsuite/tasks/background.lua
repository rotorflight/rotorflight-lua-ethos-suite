-- Rotorflight background task.
--
-- Registered eagerly: a background task must be running from
-- the moment the script loads, so there is nothing to gain by deferring
-- system.registerTask() itself -- deferring a required-at-boot subsystem
-- just delays work that has to happen anyway. What IS deferred is this
-- file's own loadfile() chain (see "Staged loading" below): registration
-- happens on the very first tick either way, only the disk-IO-heavy part
-- moves off the frame that blocks the UI.
--
-- This subsystem owns the message bus lifecycle, the MSP transport/queue
-- lifecycle (tasks/msp/*), and connection/battery tracking (tasks/session.lua).
-- All of that is kept private: the system tool and dashboard widget may
-- only interact with MSP by publishing a message to the "msp.request"
-- topic on lib/bus.lua (see tasks/msp/queue.lua for the message shape and
-- lib/msp_pid_tuning.lua for an example of building one), and may only
-- learn about connection/battery state via the "session.update" topic (see
-- tasks/session.lua). This module never reads or writes anything
-- belonging to the system tool or the dashboard widget.
--
-- Staged loading: on device, this file's loadfile() chain -- bus/
-- settingsStore/session/etc, each its own disk-open+compile, not CPU work
-- -- measured ~1s+ (see main.lua's boot timing). Prior to this, everything
-- below loaded synchronously at module-load time, before init() was even
-- called, blocking whatever frame loadfile("tasks/background.lua")() ran
-- in for that whole ~1s straight -- a visible stutter on real hardware
-- even though the PC simulator's near-zero disk latency never showed it.
-- loadSteps below is that same chain (minus bus.lua -- see taskInit())
-- reordered into a plain list of closures; this file's own module-load
-- time is now near-instant (nothing but function definitions), and
-- system.registerTask() happens on the first tick same as before.
--
-- Two things pace how/when loadSteps actually runs, in the order they
-- were found necessary -- and one thing that was tried and reverted:
--
-- 1. BOOT_DEFER_S: taskWakeup() does nothing at all -- not even one step
--    -- until this many seconds have passed since taskInit(). Ethos's own
--    boot sequence (other widgets/tasks loading, initial screen paint) is
--    itself heavy disk/CPU competition during that same window, and this
--    file's loadfile() chain was fighting that contention rather than
--    waiting it out. Confirmed on device: tasks/session.lua's own load
--    (the single biggest step) dropped from ~1.0s while contending with
--    the boot storm to ~0.68s once deferred past it -- back to the same
--    number measured with no staging at all.
-- 2. Once past the defer window, taskWakeup() runs every remaining step
--    to completion in that one call -- no further per-tick splitting.
--    An earlier version DID split further, spending only up to a small
--    time budget per call and yielding the rest to later ticks, on the
--    theory that system.registerTask()'s wakeup() cadence might still be
--    frame-rate-like even post-defer. Measured on device: 12 steps whose
--    own costs summed to ~1.15s took 7.5s of *wall time* across 4 calls
--    to finish -- ~6.3s of that was pure idle time between calls, for no
--    smoothing benefit, because wakeup() cadence turned out to be sparse
--    (multi-second gaps) even in steady state, not just during the boot
--    storm. Budgeting per call only helps when ticks are frequent enough
--    that spreading work finely reduces the worst single block; here the
--    scarce resource was getting a tick at all, not CPU time once one
--    arrived, and tasks/session.lua's own single step (~0.68s) already
--    exceeded any reasonably small budget by itself regardless. Once the
--    defer has already bought contention-free disk access, there's
--    nothing left to spread the remaining ~1.1-1.2s across.
-- 3. bus.lua itself loads synchronously in taskInit(), before either of
--    the above -- see taskInit() for why: the "msp.request" subscription
--    it sets up needs to exist for the *entire* defer+load window, not
--    just once loadSteps starts.
--
-- taskInit() otherwise stays trivial: whether Ethos calls `init`
-- synchronously inside registerTask() or on a later tick isn't
-- documented, so nothing here can assume which -- only taskWakeup() is
-- unambiguously a per-tick callback. All the real first-time setup that
-- used to live in taskInit() now lives in runDeferredInit(), invoked from
-- taskWakeup() the tick loadSteps finishes.
--
-- Until loadSteps finishes, mspQueue/session/etc are all nil -- nothing
-- in taskWakeup() runs until then, and neither does publishTaskStatus(),
-- so "task.status" (which the app already treats as "background task is
-- ready" -- see lib/bus.lua's header on why that topic is retained) simply
-- fires later than before instead of firing against half-loaded state.
-- The one thing that starts before loadSteps finishes -- before the defer
-- window even starts, in fact -- is the "msp.request" subscription
-- (bus.lua, taskInit()): deliberately early, and buffered rather than
-- handled inline, so a request published while the defer/load window is
-- still in progress isn't silently dropped (lib/bus.lua doesn't retain/
-- replay "msp.request" the way it does "task.status"). See
-- pendingMspRequests below.

local bus, settingsStore, debugLog, mspCommon, mspTransportSelect, Scheduler,
      telemetrySensors, mspQueue, session, logging, audioEvents, audioSwitches,
      scheduler

local TASK_STATUS_INTERVAL = 0.5
local MEMORY_LOG_INTERVAL = 5
-- Cheap: a couple of model.getModule()/:enable() field reads, no loadfile
-- -- see checkTransportChange() below for why this can be polled instead
-- of driven off a specific model/module-change event.
local TRANSPORT_RECHECK_INTERVAL = 2

local protocol -- "sport"|"crsf", set at init and kept current by
                -- checkTransportChange() below; see tasks/msp/transport_select.lua
local moduleNumber -- RF module bay (0 = internal, 1 = external) the current "sport"
                    -- transport is bound to; kept alongside protocol since two
                    -- module bays can both report "sport" (see transport_select.lua)
local transport -- kept current alongside protocol; passed through so session.lua can drive
                 -- protocol-specific sensor work (e.g. tasks/elrs_sensors.lua's
                 -- custom-telemetry frame pop) without a second loadfile of it
local simSensors -- tasks/sim_sensors.lua, loadfile'd (see runDeferredInit below) only when
                  -- system.getVersion().simulation == true -- stays nil, and the
                  -- module itself is never parsed/loaded, on real hardware
local lastTaskStatusAt = nil
local lastMemoryLogAt = nil
local memoryLogsEnabled = false

-- Buffered here (see the header comment above) rather than handled inline,
-- because mspQueue/session -- which the real handler needs -- don't exist
-- yet when bus.subscribe("msp.request", ...) first runs. Drained by
-- runDeferredInit() once both do.
local pendingMspRequests = {}
local mspRequestsReady = false

local function handleMspRequest(message)
  if message and message.clearQueue then
    mspQueue:clear()
    if not message.command then return end
  end
  if message and message.sessionBatteryProfile ~= nil and type(session.setBatteryProfile) == "function" then
    local originalProcessReply = message.processReply
    local selectedProfile = message.sessionBatteryProfile
    message.processReply = function(msg, buf)
      session.setBatteryProfile(selectedProfile)
      if originalProcessReply then originalProcessReply(msg, buf) end
    end
  end
  mspQueue:add(message)
end

local function onMspRequestReceived(message)
  if mspRequestsReady then
    handleMspRequest(message)
  else
    pendingMspRequests[#pendingMspRequests + 1] = message
  end
end

local function publishTaskStatus(now)
  lastTaskStatusAt = now or os.clock()
  bus.publish("task.status", {
    running = true,
    protocol = protocol,
    updatedAt = lastTaskStatusAt,
  })
end

local function logMemoryUsage(now)
  if not memoryLogsEnabled then return end
  if lastMemoryLogAt and (now - lastMemoryLogAt) < MEMORY_LOG_INTERVAL then return end

  lastMemoryLogAt = now

  local mem = system.getMemoryUsage and system.getMemoryUsage() or {}
  print(string.format(
    "[bgtask mem] lua=%.1fKB ramAvail=%.1fKB luaRamAvail=%.1fKB bmpRamAvail=%.1fKB stackAvail=%.1fKB",
    collectgarbage("count"),
    (mem.ramAvailable or 0) / 1024,
    (mem.luaRamAvailable or 0) / 1024,
    (mem.luaBitmapsRamAvailable or 0) / 1024,
    (mem.mainStackAvailable or 0) / 1024
  ))
end

local function onSettingsUpdate(snapshot)
  memoryLogsEnabled = settingsStore.memoryLogsEnabled(snapshot)
end

-- system.registerTask's `init` runs once for this task's whole lifetime,
-- not per model switch -- so if the radio's active model changes to one
-- with a different receiver protocol (S.Port <-> CRSF/ELRS) without the
-- background task itself reloading, `protocol`/`transport` would otherwise
-- stay stuck at whatever runDeferredInit() first saw.
--
-- Detect-and-hold: only ACTS when detect()'s answer actually differs from
-- the held `protocol` -- but still polls detect() itself every tick this
-- runs (via TRANSPORT_RECHECK_INTERVAL), rather than gating that polling
-- behind a separate model.path()/module-enable comparison. That gate was
-- tried and reverted: detect() can legitimately return a *transient*
-- "sport" fallback (external module enabled but its CRSF telemetry source
-- not populated yet -- see tasks/msp/transport_select.lua) while
-- model.path()/module-enable state itself never changes again, which would
-- leave protocol wrongly stuck for the rest of the session with a gate in
-- front of the retry. detect() itself now reads stable model-config values
-- (which RF module bay is *enabled*), not a telemetry source's mere
-- presence, so polling it plainly can't cause the flapping the RSSI-
-- presence version could.
local function checkTransportChange()
  local detected, detectedModule = mspTransportSelect.detect()
  if detected == protocol and detectedModule == moduleNumber then return end

  -- Drop whatever the old transport had in flight before swapping -- a
  -- half-sent MSPv2 chunk (or its expected reply) means nothing to the new
  -- transport. Queue:clear() drains it through the *old* transport (still
  -- set on mspCommon at this point) before setTransport() below replaces it.
  mspQueue:clear()
  protocol = detected
  moduleNumber = detectedModule
  transport = mspTransportSelect.load(protocol, moduleNumber)
  mspCommon.setTransport(transport)
  if telemetrySensors then telemetrySensors.reset() end
  print("[bgtask] transport changed: " .. tostring(protocol) .. " (module " .. tostring(moduleNumber) .. ")")
end

-- Everything taskInit() used to do synchronously, now deferred until
-- loadSteps (below) finishes -- see the header comment for why.
local function runDeferredInit()
  transport, protocol, moduleNumber = mspTransportSelect.select()
  mspCommon.setTransport(transport)
  session.setTelemetrySensors(telemetrySensors)
  logging.setTelemetrySensors(telemetrySensors)
  audioSwitches.setTelemetrySensors(telemetrySensors)
  local initialSettings = settingsStore.load()
  logging.setSettings(initialSettings)
  audioEvents.setSettings(initialSettings)
  audioSwitches.setSettings(initialSettings)
  onSettingsUpdate(initialSettings)
  bus.subscribe("settings.update", onSettingsUpdate)

  mspRequestsReady = true
  for i = 1, #pendingMspRequests do
    handleMspRequest(pendingMspRequests[i])
  end
  pendingMspRequests = {}

  scheduler:clear()
  lastMemoryLogAt = nil
  scheduler:add("transport_recheck", TRANSPORT_RECHECK_INTERVAL, checkTransportChange)
  scheduler:add("session", 0.05, function()
    session.wakeup(mspQueue, protocol, transport, simSensors)
  end)
  scheduler:add("logging", 0.25, function()
    logging.wakeup(protocol)
  end)
  scheduler:add("audio_events", 0.25, function()
    audioEvents.wakeup()
  end)
  scheduler:add("audio_switches", 0.25, function()
    audioSwitches.wakeup(protocol)
  end)

  -- Only ever loadfile'd/scheduled here, behind this one check -- see
  -- tasks/sim_sensors.lua's own header for why it costs nothing otherwise.
  if system.getVersion().simulation == true then
    simSensors = simSensors or assert(loadfile("tasks/sim_sensors.lua"))()
    scheduler:add("sim_sensors", 2, function()
      simSensors.wakeup()
    end)
  end

  -- Published last, once mspQueue/msp.request/scheduler jobs are all
  -- actually live -- see the header comment on why other subsystems
  -- already treat this as the "background task is ready" signal.
  publishTaskStatus()
end

-- All run to completion in a single taskWakeup() call, once past the
-- boot-storm defer window -- see the header comment above. mspQueue/
-- session/logging/audio_events/audio_switches are all handed the
-- bus/settingsStore/debugLog/mspCommon instances already loaded earlier
-- in this same list explicitly, rather than loadfile()'ing their own
-- copies -- see the note atop tasks/msp/queue.lua and tasks/session.lua
-- for why: loadfile() has no require()-style caching, so every redundant
-- loadfile() of the same small shared module was paying real disk-open/
-- compile cost on device even though the module itself self-caches via
-- package.loaded.
local loadSteps = {
  function()
    settingsStore = assert(loadfile("lib/settings_store.lua"))()
  end,
  function()
    debugLog = assert(loadfile("lib/debug_log.lua"))(bus, settingsStore)
  end,
  function()
    mspCommon = assert(loadfile("tasks/msp/common.lua"))()
  end,
  function()
    mspTransportSelect = assert(loadfile("tasks/msp/transport_select.lua"))()
  end,
  function()
    Scheduler = assert(loadfile("tasks/scheduler.lua"))()
    scheduler = Scheduler.new()
  end,
  function()
    telemetrySensors = assert(loadfile("lib/telemetry_sensors.lua"))()
  end,
  function()
    mspQueue = assert(loadfile("tasks/msp/queue.lua"))().new(mspCommon, debugLog)
  end,
  function()
    session = assert(loadfile("tasks/session.lua"))(bus, settingsStore, debugLog)
  end,
  function()
    logging = assert(loadfile("tasks/logging.lua"))(bus, settingsStore, debugLog)
  end,
  function()
    audioEvents = assert(loadfile("tasks/audio_events.lua"))(bus, settingsStore)
  end,
  function()
    audioSwitches = assert(loadfile("tasks/audio_switches.lua"))(bus, settingsStore)
  end,
}
local loadStepIndex = 1
local loadComplete = false

-- Boot-storm defer: don't even attempt the first load step until
-- BOOT_DEFER_S has passed since this task's init(). The previous commit
-- found taskWakeup()'s own cadence unpredictably slow specifically during
-- the boot window -- Ethos is doing its own heavy disk/CPU work then too
-- (other widgets/tasks loading, initial screen paint), and this file's
-- loadfile() chain was competing with that rather than waiting it out.
-- Idling first, then loading once the radio has actually finished
-- booting, sidesteps that contention instead of trying to survive it.
-- Tested at both 2s and 5s on device: the same ~2/3 of boots still showed
-- tasks/session.lua's own load elevated (~1.0s vs. the clean ~0.68s) at
-- either value, with no improvement from the extra 3s wait -- pointing at
-- intermittent SD-card I/O latency (wear-leveling/GC/flash jitter) rather
-- than a fixed-duration boot storm this can wait out. Left at 2s since 5s
-- measured no benefit; not expected to fully eliminate the remaining
-- variance, but the delay itself isn't worth paying further for.
local BOOT_DEFER_S = 2.0
local bootDeferUntil

local function taskInit()
  -- Deliberately kept to trivial, near-instant work -- see the header
  -- comment on why: everything else real happens in taskWakeup(), the one
  -- callback here unambiguously driven per-tick by Ethos.
  loadStepIndex = 1
  loadComplete = false
  bootDeferUntil = os.clock() + BOOT_DEFER_S

  -- bus.lua loads here, synchronously, rather than as a deferred/staged
  -- step below -- the "msp.request" subscription (and pendingMspRequests
  -- buffer) needs to exist for the ENTIRE defer+load window, not just once
  -- loadSteps itself starts running post-defer. Cheap, unlike the rest of
  -- this file's loadfile() chain, so doing it here doesn't reintroduce the
  -- blocking BOOT_DEFER_S is otherwise there to avoid.
  mspRequestsReady = false
  pendingMspRequests = {}
  bus = assert(loadfile("lib/bus.lua"))()
  bus.subscribe("msp.request", onMspRequestReceived)
end

local function taskWakeup()
  if not loadComplete then
    if os.clock() < bootDeferUntil then
      -- Still inside the boot-storm defer window -- do nothing at all,
      -- not even a step, until it passes.
      return
    end
    -- Past the defer window: run every remaining step to completion in
    -- this one call, no further per-tick splitting -- see the header
    -- comment on why that was tried and reverted.
    for i = loadStepIndex, #loadSteps do
      loadSteps[i]()
    end
    loadStepIndex = #loadSteps + 1
    loadComplete = true
    runDeferredInit()
    return
  end

  mspQueue:processQueue()
  scheduler:wakeup()
  local now = os.clock()
  logMemoryUsage(now)
  if not lastTaskStatusAt or (now - lastTaskStatusAt) >= TASK_STATUS_INTERVAL then
    publishTaskStatus(now)
  end
end

local function taskEvent()
end

local function init()
  system.registerTask({
    key = "rf2bg",
    name = "Rotorflight [Background]",
    init = taskInit,
    wakeup = taskWakeup,
    event = taskEvent,
  })
end

return {init = init}
