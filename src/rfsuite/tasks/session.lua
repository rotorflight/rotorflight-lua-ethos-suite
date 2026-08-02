-- Minimal connection + battery-state tracking, owned by the background
-- task. Loaded by tasks/background.lua, which passes it the *same* mspQueue
-- instance it created (never a second loadfile()'d copy -- see the note in
-- tasks/msp/queue.lua about why that breaks), plus the active transport
-- protocol name ("sport"|"crsf") for lib/telemetry_sensors.lua and the
-- transport instance itself (for tasks/elrs_sensors.lua's custom-telemetry
-- frame pop on CRSF -- also never loadfile'd a second time; this file is
-- its sole owner, same as lib/frsky_sensors.lua's FrskySensors instance).
--
-- Owns a private `session` table -- nothing outside tasks/ ever gets a
-- reference to it. Other subsystems learn about connection/battery changes
-- only by subscribing to lib/bus.lua's "session.update" topic, which
-- carries a fresh snapshot copy each time, never the live table.
--
-- Deliberately slimmer than the original suite's connection handling: no
-- telemetry-sensor-discovery/link-watchdog layer, no task-manifest runner.
-- "Connected" follows Ethos's native TELEMETRY_ACTIVE flag. On the rising
-- edge, a small handshake (lib/msp_handshake.lua) fetches FC version, MCU
-- UID, craft name, syncs the FC's clock, and reads battery/smartfuel config
-- -- the MSP-calling subset of the original suite's onconnect/postconnect
-- task manifests. There is no idle MSP heartbeat.

local bus = assert(loadfile("lib/bus.lua"))()
local handshake = assert(loadfile("lib/msp_handshake.lua"))()
local mspApiVersion = assert(loadfile("lib/msp_api_version.lua"))()
local settingsStore = assert(loadfile("lib/settings_store.lua"))()
local mspBattery = assert(loadfile("lib/msp_battery.lua"))()
local dataflashSummary = assert(loadfile("lib/msp_dataflash_summary.lua"))()
local governorConfig = assert(loadfile("lib/msp_governor_config.lua"))()
local modelPreferences = assert(loadfile("lib/model_preferences.lua"))()
local flightStats = assert(loadfile("lib/msp_flight_stats.lua"))()
local eeprom = assert(loadfile("lib/msp_eeprom.lua"))()
local smartfuelReserve = assert(loadfile("lib/smartfuel_reserve.lua"))()
local SmartFuel = assert(loadfile("lib/smartfuel_calc.lua"))()
local DiySensor = assert(loadfile("lib/diy_sensor.lua"))()
local telemetryConfig = assert(loadfile("lib/msp_telemetry_config.lua"))()
local flightTimer = assert(loadfile("tasks/flight_timer.lua"))()
local debugLog = assert(loadfile("lib/debug_log.lua"))()

local TELEMETRY_VALUE_INTERVAL = 0.5
local PROFILE_INTERVAL = 0.5
local ADJUSTMENT_INTERVAL = 0.2
local ELRS_SENSOR_INTERVAL = 0.18
local BLACKBOX_INTERVAL = 20
local SENSOR_CHECKS_ENABLED = true

-- Computed once at load, matching tasks/background.lua's own gate for
-- tasks/sim_sensors.lua. The Ethos simulator has no real Rx RSSI source, so
-- tasks/msp/transport_select.lua always resolves protocol == "sport" there
-- -- used below to keep runHandshake() from also provisioning real S.Port
-- sensors (lib/frsky_sensors.lua) on top of the ones tasks/sim_sensors.lua
-- already creates at their own appIds, and to pick the "sim" candidates in
-- lib/telemetry_sensors.lua's lookups instead of "sport"'s real appIds.
local isSim = system.getVersion().simulation == true

-- Ethos's own native telemetry-link-active flag (the original suite aliases
-- this same source as `tlm`). Driven by the RF
-- link's own quality tracking, so connection edges are detected from this
-- signal rather than a constant MSP heartbeat.
local tlm = system.getSource({category = CATEGORY_SYSTEM_EVENT, member = TELEMETRY_ACTIVE})

local session = {
  connected = false,
  voltage = nil,
  fcVersion = nil,
  rfVersion = nil,
  apiVersionMajor = nil,
  apiVersionMinor = nil,
  -- true/false once lib/msp_api_version.lua's read completes; nil while
  -- still unknown (never reads as "unsupported" -- see its own isSupported()).
  apiVersionSupported = nil,
  mcuId = nil,
  craftName = nil,
  clockSynced = false,
  batteryConfig = nil, -- {batteryCapacity, cellCount, vbatMinCell, vbatMaxCell, vbatFullCell, vbatWarningCell, consumptionWarningPercentage}
  consumption = nil,
  current = nil,
  throttlePercent = nil,
  rpm = nil,
  linkQuality = nil,
  tempEsc = nil,
  tempMcu = nil,
  becVoltage = nil,
  smartfuelMode = nil, -- 0 = FC not computing it (run the local fallback), 1/2/3 = mirror the FC's own value
  smartfuelVoltageFallPerSecond = nil,
  smartfuelChargeDropPerSecond = nil,
  fuelPercent = nil,
  governorMode = nil,
  governorState = nil,
  mspTransport = nil,
  telemetrySlots = nil, -- 40-entry S.Port sensor-slot array, see lib/msp_telemetry_config.lua
  pidProfile = nil,
  rateProfile = nil,
  batteryProfile = nil,
  adjFunction = nil,
  adjValue = nil,
  timerLive = 0,
  timerSession = 0,
  timerFlightCounted = false,
  timerTarget = 300,
  modelPreferences = nil,
  modelPreferencesFile = nil,
  modelPreferencesMcuId = nil,
  modelStats = nil,
  bblFlags = nil,
  bblSize = nil,
  bblUsed = nil,
  -- Arm state, read from the FC's own "armflags" telemetry sensor --
  -- matches the original suite's own app/lib/utils.lua
  -- armFlagsToIsArmed(): raw value 1 or 3 means armed, 0 or 2 disarmed
  -- (bit 0 of the arm-status flags), anything else (nil -- sensor not
  -- broadcasting yet) leaves isArmed at its last known value rather than
  -- guessing. The one current consumer is app/pages/configuration.lua's
  -- save flow, which must not trigger MSP_REBOOT while the aircraft could
  -- be armed -- see lib/msp_reboot.lua's own comment for why this is the
  -- only safety gate on that command (firmware's own MSP_REBOOT handler
  -- has none).
  isArmed = nil,
  -- Why-can't-arm bitmask, read from the FC's own "armdisableflags"
  -- telemetry sensor -- see widgets/dashboard/context.lua's
  -- armingDisableFlagsToString() for how the dashboard's governor/armflags
  -- objects turn this into a human-readable reason list.
  armDisableFlags = nil,
}

local localSmartFuel = SmartFuel.new()

-- Pushed unconditionally whenever updateFuel() runs, regardless of
-- smartfuelMode -- mirrors the original suite's smart.lua, which
-- creates/updates this sensor unconditionally too (see updateFuel()'s
-- comment for why the mode-gated version was wrong). If something else
-- already broadcasts natively at this appId, lib/diy_sensor.lua's own
-- existing-sensor check means this reuses it rather than duplicating it.
local SMARTFUEL_APP_ID = 0x5FE1
local smartfuelSensor = DiySensor.new(SMARTFUEL_APP_ID, "Smart Fuel", UNIT_PERCENT, -1, 100)

-- Only acted on for the S.Port protocol -- see runHandshake() below. On
-- CRSF, tasks/elrs_sensors.lua's own (differently-shaped, reactive rather
-- than config-provisioned) mechanism handles custom-sensor creation
-- instead -- see wakeup() below. Both lib/frsky_sensors.lua and
-- tasks/elrs_sensors.lua are loadfile()'d lazily, on first actual need,
-- rather than unconditionally here -- only one of the two protocols is
-- ever active per session, so this is ~20KB of parsing neither Ethos nor
-- the FC needed to pay for on that session's other protocol (same
-- lazy-load-per-protocol reasoning as lib/telemetry_sensors.lua's own
-- candidate-file split). Kept around once loaded, not reloaded per
-- connection, in case tasks/background.lua's checkTransportChange() picks
-- a different protocol later in the same run.
local frskySensors = nil
local elrsSensors = nil

local function ensureFrskySensors()
  if not frskySensors then
    local FrskySensors = assert(loadfile("lib/frsky_sensors.lua"))()
    frskySensors = FrskySensors.new()
  end
  return frskySensors
end

local function ensureElrsSensors()
  if not elrsSensors then
    elrsSensors = assert(loadfile("tasks/elrs_sensors.lua"))()
  end
  return elrsSensors
end

local telemetrySensors = nil

local lastBeepAt = 0
local nextScheduledAt = {}
local statsReadInFlight = false
local statsWriteInFlight = false
local blackboxReadInFlight = false
local pendingStatsSync = false
local pendingStatsSyncAt = nil
-- The Ethos model's own name, as it was before settings.general.syncname
-- last overwrote it with the FC's craft name -- captured once per connect
-- (see the craft-name handshake below) and restored on disconnect, same
-- round-trip as master's own postconnect/craftname.lua + lib/utils.lua.
local originalModelName = nil

local function resetScheduler()
  for key in pairs(nextScheduledAt) do
    nextScheduledAt[key] = nil
  end
end

local function shouldRunScheduled(key, interval, now)
  local nextAt = nextScheduledAt[key]
  if nextAt and now < nextAt then
    return false
  end

  nextScheduledAt[key] = now + interval
  return true
end

local function copyBatteryConfig(config)
  if type(config) ~= "table" then return nil end
  local profiles = nil
  if type(config.profiles) == "table" then
    profiles = {}
    for i = 0, 5 do
      profiles[i] = config.profiles[i]
    end
  end
  return {
    batteryCapacity = config.batteryCapacity,
    cellCount = config.cellCount,
    vbatMinCell = config.vbatMinCell,
    vbatMaxCell = config.vbatMaxCell,
    vbatFullCell = config.vbatFullCell,
    vbatWarningCell = config.vbatWarningCell,
    consumptionWarningPercentage = config.consumptionWarningPercentage,
    profiles = profiles,
  }
end

local function normalizeBatteryProfile(value)
  local profile = tonumber(value)
  if profile == nil then return nil end
  profile = math.floor(profile)
  if profile >= 1 and profile <= 6 then return profile - 1 end
  if profile >= 0 and profile <= 5 then return profile end
  return nil
end

local function copyStats(stats)
  if type(stats) ~= "table" then return nil end
  return {
    flightcount = stats.flightcount,
    lastflighttime = stats.lastflighttime,
    totalflighttime = stats.totalflighttime,
  }
end

local function publish()
  bus.publish("session.update", {
    connected = session.connected,
    voltage = session.voltage,
    fcVersion = session.fcVersion,
    rfVersion = session.rfVersion,
    apiVersionMajor = session.apiVersionMajor,
    apiVersionMinor = session.apiVersionMinor,
    apiVersionSupported = session.apiVersionSupported,
    mcuId = session.mcuId,
    craftName = session.craftName,
    batteryConfig = copyBatteryConfig(session.batteryConfig),
    consumption = session.consumption,
    current = session.current,
    throttlePercent = session.throttlePercent,
    rpm = session.rpm,
    linkQuality = session.linkQuality,
    tempEsc = session.tempEsc,
    tempMcu = session.tempMcu,
    becVoltage = session.becVoltage,
    fuelPercent = session.fuelPercent,
    governorMode = session.governorMode,
    governorState = session.governorState,
    mspTransport = session.mspTransport,
    pidProfile = session.pidProfile,
    rateProfile = session.rateProfile,
    batteryProfile = session.batteryProfile,
    adjFunction = session.adjFunction,
    adjValue = session.adjValue,
    timerLive = session.timerLive,
    timerSession = session.timerSession,
    timerFlightCounted = session.timerFlightCounted,
    timerTarget = session.timerTarget,
    modelStats = copyStats(session.modelStats),
    bblFlags = session.bblFlags,
    bblSize = session.bblSize,
    bblUsed = session.bblUsed,
    isArmed = session.isArmed,
    armDisableFlags = session.armDisableFlags,
  })
end

local function updateModelSnapshots()
  if session.modelPreferences then
    session.modelStats = modelPreferences.stats(session.modelPreferences)
    session.timerTarget = modelPreferences.timerTarget(session.modelPreferences)
  else
    session.modelStats = nil
    session.timerTarget = 300
  end
end

local function saveModelPreferences()
  if session.modelPreferences and session.modelPreferencesFile then
    modelPreferences.save(session.modelPreferencesFile, session.modelPreferences)
  end
  updateModelSnapshots()
  publish()
end

local function loadModelPreferences()
  if not session.mcuId then return false end
  if session.modelPreferences and session.modelPreferencesMcuId == session.mcuId then return true end
  session.modelPreferences, session.modelPreferencesFile = modelPreferences.load(session.mcuId)
  session.modelPreferencesMcuId = session.mcuId
  updateModelSnapshots()
  publish()
  return true
end

local function scheduleStatsSync(delay)
  pendingStatsSync = true
  pendingStatsSyncAt = os.clock() + (delay or 1)
end

local function localStatsForRemote()
  local stats = session.modelStats or modelPreferences.stats(session.modelPreferences)
  return {
    flightcount = tonumber(stats and stats.flightcount) or 0,
    totalflighttime = tonumber(stats and stats.totalflighttime) or 0,
  }
end

local function mergeRemoteStats(remote)
  local localStats = localStatsForRemote()
  local remoteCount = tonumber(remote and remote.flightcount) or 0
  local remoteTime = tonumber(remote and remote.totalflighttime) or 0
  local localCount = tonumber(localStats.flightcount) or 0
  local localTime = tonumber(localStats.totalflighttime) or 0

  if remoteCount > localCount or remoteTime > localTime then
    session.modelPreferences = modelPreferences.setStats(session.modelPreferences, {
      flightcount = math.max(remoteCount, localCount),
      totalflighttime = math.max(remoteTime, localTime),
      lastflighttime = session.modelStats and session.modelStats.lastflighttime or 0,
    })
    saveModelPreferences()
    return "updated_local"
  end

  if localCount > remoteCount or localTime > remoteTime then
    return "write_remote"
  end

  return "same"
end

local function writeRemoteStats(mspQueue, remote)
  if statsWriteInFlight then return end
  local localStats = localStatsForRemote()
  local merged = flightStats.clone(remote)
  merged.flightcount = localStats.flightcount
  merged.totalflighttime = localStats.totalflighttime
  statsWriteInFlight = true
  mspQueue:add(flightStats.buildWriteMessage(merged, function()
    statsWriteInFlight = false
    mspQueue:add(eeprom.buildWriteMessage())
  end, function(reason)
    statsWriteInFlight = false
    print("[session] FLIGHT_STATS write failed: " .. tostring(reason))
  end))
end

local function syncStatsWithFc(mspQueue)
  if not mspQueue or statsReadInFlight or statsWriteInFlight then return end
  if session.connected ~= true or session.isArmed == true then return end
  if not loadModelPreferences() then return end

  statsReadInFlight = true
  mspQueue:add(flightStats.buildReadMessage(function(remote)
    statsReadInFlight = false
    local action = mergeRemoteStats(remote)
    if action == "write_remote" then
      writeRemoteStats(mspQueue, remote)
    end
  end, function(reason)
    statsReadInFlight = false
    print("[session] FLIGHT_STATS read failed: " .. tostring(reason))
  end))
end

local function updateBlackboxSummary(mspQueue)
  if not mspQueue or blackboxReadInFlight then return end
  if session.connected ~= true or session.isArmed == true then return end

  blackboxReadInFlight = true
  mspQueue:add(dataflashSummary.buildReadMessage(function(summary)
    blackboxReadInFlight = false
    session.bblFlags = summary.flags
    session.bblSize = summary.total
    session.bblUsed = summary.used
    publish()
  end, function(reason)
    blackboxReadInFlight = false
    print("[session] DATAFLASH_SUMMARY read failed: " .. tostring(reason))
  end))
end

-- Matches rfsuite.utils.playConnectBeep() in the original suite: play
-- audio/beep.wav (the same asset, copied from that project) right after a
-- successful connect, debounced to at most once every 2 seconds. There is
-- no equivalent disconnect chime at this layer in the original either, so
-- setConnected(false) below stays silent.
local function playConnectBeep()
  local now = os.clock()
  if (now - lastBeepAt) < 2.0 then return end
  lastBeepAt = now
  system.playFile("audio/beep.wav")
end

-- Runs once per genuine disconnect -> connect transition. Each read is
-- independently gated on "don't already have it", so a slow/failed
-- individual read just leaves that one field nil rather than blocking the
-- others -- there is no manifest/retry-queue runner here, only the
-- queue's own per-message retry (see tasks/msp/queue.lua).
local function runHandshake(mspQueue, protocol)
  if session.apiVersionMajor == nil then
    -- Developer-only, and only reachable in the simulator (real hardware
    -- always ignores simulatorResponse -- see tasks/msp/queue.lua's isSim
    -- branch): lets a dev exercise the "unsupported firmware family"
    -- dashboard state on demand instead of needing incompatible real
    -- hardware to test it against.
    local simResponse = nil
    if isSim then
      local devSettings = settingsStore.load()
      local mode = settingsStore.simulatedApiVersionMode(devSettings)
      simResponse = mspApiVersion.simResponseForVersion(mode)
    end
    mspQueue:add(mspApiVersion.buildReadMessage(function(data)
      session.apiVersionMajor = data.major
      session.apiVersionMinor = data.minor
      session.apiVersionSupported = mspApiVersion.isSupported(data.major, data.minor)
      publish()
    end, nil, simResponse))
  end

  if not session.fcVersion then
    mspQueue:add(handshake.buildFcVersionReadMessage(function(data)
      session.fcVersion = data.fcVersion
      session.rfVersion = data.rfVersion
      publish()
    end))
  end

  if not session.mcuId then
    mspQueue:add(handshake.buildUidReadMessage(function(mcuId)
      session.mcuId = mcuId
      loadModelPreferences()
      scheduleStatsSync(0)
      publish()
    end))
  end

  if not session.craftName then
    mspQueue:add(handshake.buildNameReadMessage(function(name)
      session.craftName = name
      -- Mirrors master's postconnect/craftname.lua: overwrite the pilot's
      -- own Ethos model name with the FC's craft name, opt-in only (see
      -- lib/settings_store.lua's syncname). originalModelName is captured
      -- once per connect (not per handshake retry -- `not originalModelName`
      -- guards that) and restored in setConnected(false) below, same
      -- round-trip as master's own lib/utils.lua.
      if settingsStore.syncNameEnabled(settingsStore.load()) and model and model.name
        and session.craftName and session.craftName ~= "" then
        if not originalModelName then
          local ok, current = pcall(model.name)
          if ok then originalModelName = current end
        end
        pcall(model.name, session.craftName)
      end
      publish()
    end))
  end

  if not session.clockSynced then
    mspQueue:add(handshake.buildRtcSyncMessage(function()
      session.clockSynced = true
    end))
  end

  if not session.batteryConfig then
    mspQueue:add(mspBattery.buildBatteryConfigReadMessage(function(data)
      session.batteryConfig = data
      publish()
    end))
  end

  if session.smartfuelMode == nil then
    mspQueue:add(mspBattery.buildSmartfuelConfigReadMessage(function(data)
      session.smartfuelMode = data.mode
      session.smartfuelVoltageFallPerSecond = data.voltageFallPerSecond
      session.smartfuelChargeDropPerSecond = data.chargeDropPerSecond
      debugLog.print("[session] SMARTFUEL_CONFIG read ok: mode=" .. tostring(data.mode))
      publish()
    end, function()
      -- SMARTFUEL_CONFIG (cmd 0x4000) needs API >= 12.0.9 -- right at this
      -- rebuild's floor -- and firmware feature rollout can lag the API
      -- version bump, so a real FC may simply not answer it yet. Without
      -- this, a failed read left smartfuelMode nil forever, and
      -- updateFuel()'s very first line bails out on nil -- silently
      -- disabling fuel% *and* lib/diy_sensor.lua's smartfuel sensor for
      -- the whole connection, never falling back to the local estimator
      -- the mode==0 branch exists for. An unsupported command is the
      -- strongest possible case for that fallback, so treat it exactly
      -- like a real mode-0 reply instead of leaving it unresolved.
      session.smartfuelMode = 0
      debugLog.print("[session] SMARTFUEL_CONFIG read failed; falling back to local smartfuel (mode=0)")
      publish()
    end))
  end

  if session.governorMode == nil then
    mspQueue:add(governorConfig.buildReadMessage(function(data)
      session.governorMode = data.gov_mode
      publish()
    end, function()
      session.governorMode = 0
      publish()
    end))
  end

  -- Fetched regardless of protocol (cheap, and tasks/elrs_sensors.lua wants
  -- the same slot data for its own SID-relevance filtering on CRSF) --
  -- provisioning itself only happens for S.Port here; see wakeup() below
  -- for where the CRSF side of this gets used.
  if not session.telemetrySlots then
    mspQueue:add(telemetryConfig.buildReadMessage(function(slots)
      session.telemetrySlots = slots
      local assigned = 0
      for i = 1, #slots do
        if slots[i] and slots[i] ~= 0 then assigned = assigned + 1 end
      end
      debugLog.print("[session] TELEMETRY_CONFIG read ok: " .. assigned .. "/" .. #slots .. " slots assigned")
      -- Skipped in the simulator: tasks/sim_sensors.lua already creates its
      -- own pid_profile/rate_profile/battery_profile/etc. sensors at their
      -- own appIds, and there's no real S.Port wire here for these
      -- placeholders to ever receive a value on -- provisioning them too
      -- just left duplicate "PID Profile"/"Rate Profile"/"Battery Profile"
      -- sensors sitting alongside the sim ones.
      if protocol == "sport" and not isSim then
        ensureFrskySensors():provision(slots)
      end
    end, function()
      debugLog.print("[session] TELEMETRY_CONFIG read failed")
    end))
  end
end

local function setConnected(value, mspQueue, protocol)
  if session.connected == value then return end
  session.connected = value
  resetScheduler()

  if value then
    debugLog.print("[session] connected (protocol=" .. tostring(protocol) .. ")")
    playConnectBeep()
    runHandshake(mspQueue, protocol)
  else
    debugLog.print("[session] disconnected")
    -- Restore whatever the Ethos model name was before syncname (see the
    -- craft-name handshake above) last overwrote it -- must run before
    -- session.craftName is wiped below, since it's this connect's own
    -- captured originalModelName that's being restored, not a fresh read.
    if originalModelName and model and model.name then
      pcall(model.name, originalModelName)
    end
    originalModelName = nil
    -- Forget everything the handshake fetched so it re-runs in full on the
    -- next connect (a stale FC version/UID/battery config from a previous
    -- session -- or a different aircraft entirely -- must not survive a
    -- disconnect).
    session.fcVersion = nil
    session.rfVersion = nil
    session.apiVersionMajor = nil
    session.apiVersionMinor = nil
    session.apiVersionSupported = nil
    session.mcuId = nil
    session.craftName = nil
    session.clockSynced = false
    session.batteryConfig = nil
    session.consumption = nil
    session.current = nil
    session.throttlePercent = nil
    session.rpm = nil
    session.linkQuality = nil
    session.tempEsc = nil
    session.tempMcu = nil
    session.becVoltage = nil
    session.smartfuelMode = nil
    session.smartfuelVoltageFallPerSecond = nil
    session.smartfuelChargeDropPerSecond = nil
    session.fuelPercent = nil
    session.governorMode = nil
    session.governorState = nil
    session.telemetrySlots = nil
    session.pidProfile = nil
    session.rateProfile = nil
    session.batteryProfile = nil
    session.adjFunction = nil
    session.adjValue = nil
    session.timerLive = 0
    session.timerSession = 0
    session.timerFlightCounted = false
    session.timerTarget = 300
    session.modelPreferences = nil
    session.modelPreferencesFile = nil
    session.modelPreferencesMcuId = nil
    session.modelStats = nil
    session.bblFlags = nil
    session.bblSize = nil
    session.bblUsed = nil
    statsReadInFlight = false
    statsWriteInFlight = false
    blackboxReadInFlight = false
    pendingStatsSync = false
    pendingStatsSyncAt = nil
    flightTimer.reset()
    session.isArmed = nil
    session.armDisableFlags = nil
    localSmartFuel:reset()
    smartfuelSensor:reset()
    if telemetrySensors then telemetrySensors.reset() end
    if frskySensors then frskySensors:reset() end
    if elrsSensors then elrsSensors.reset() end
  end

  publish()
end

local function updateVoltage(protocol)
  if not telemetrySensors then return end
  local value = telemetrySensors.getValue(protocol, "voltage")
  if value ~= session.voltage then
    session.voltage = value
    publish()
  end
end

local function updateRfStatusTelemetry(protocol)
  if not telemetrySensors then return end

  local changed = false

  local current = telemetrySensors.getValue(protocol, "current")
  if current ~= session.current then
    session.current = current
    changed = true
  end

  local consumption = telemetrySensors.getValue(protocol, "consumption")
  if consumption ~= session.consumption then
    session.consumption = consumption
    changed = true
  end

  local throttlePercent = telemetrySensors.getValue(protocol, "throttle_percent")
  if throttlePercent ~= session.throttlePercent then
    session.throttlePercent = throttlePercent
    changed = true
  end

  local rpm = telemetrySensors.getValue(protocol, "rpm")
  if rpm ~= session.rpm then
    session.rpm = rpm
    changed = true
  end

  local linkQuality = telemetrySensors.getValue(protocol, "link")
  if linkQuality ~= session.linkQuality then
    session.linkQuality = linkQuality
    changed = true
  end

  if changed then publish() end
end

-- Mirrors the original suite's app/lib/utils.lua getCurrentProfile()/
-- getCurrentRateProfile()/getCurrentBatteryType(): read straight off the
-- FC's own PID/rate/battery-profile telemetry sensor (lib/frsky_sensors.lua
-- labels the native S.Port broadcast; tasks/elrs_sensors.lua's own DIY
-- sensor serves the same appId on CRSF) -- not an MSP poll. Published so
-- app/pages/pids.lua (or any future page) can react to a profile switch
-- without touching tasks/ directly.
local function updateProfiles(protocol)
  if not telemetrySensors then return end
  local pidProfile = telemetrySensors.getValue(protocol, "pid_profile")
  if pidProfile ~= session.pidProfile then
    session.pidProfile = pidProfile
    publish()
  end

  local rateProfile = telemetrySensors.getValue(protocol, "rate_profile")
  if rateProfile ~= session.rateProfile then
    session.rateProfile = rateProfile
    publish()
  end

  local batteryProfile = normalizeBatteryProfile(telemetrySensors.getValue(protocol, "battery_profile"))
  if batteryProfile ~= session.batteryProfile then
    session.batteryProfile = batteryProfile
    publish()
  end

  -- Bit 0 (ARMED, firmware src/main/fc/runtime_config.h) is the only bit
  -- that reflects current arm state -- bits 1 (WAS_EVER_ARMED) and 2
  -- (WAS_ARMED_WITH_PREARM) are historical and accumulate over a session,
  -- so a whole-byte whitelist (armFlags == 1 or 3) stops matching once
  -- either has been set (e.g. PREARM users see 5, then 7 -- both still
  -- armed). When the sensor hasn't reported yet (nil), session.isArmed
  -- keeps its last known value rather than guessing at one, same "don't
  -- overwrite a real reading with a guess" reasoning
  -- lib/telemetry_sensors.lua's own miss-retry cache already uses.
  local armFlags = telemetrySensors.getValue(protocol, "armflags")
  local isArmed
  if armFlags ~= nil then
    isArmed = (math.floor(armFlags) & 1) == 1
  end
  if isArmed ~= nil and isArmed ~= session.isArmed then
    session.isArmed = isArmed
    publish()
  end

  local armDisableFlags = telemetrySensors.getValue(protocol, "armdisableflags")
  if armDisableFlags ~= nil and armDisableFlags ~= session.armDisableFlags then
    session.armDisableFlags = armDisableFlags
    publish()
  end
end

local function setBatteryProfile(value)
  local batteryProfile = normalizeBatteryProfile(value)
  if batteryProfile == nil then return end
  if batteryProfile == session.batteryProfile then return end
  session.batteryProfile = batteryProfile
  publish()
end

local function updateAdjustment(protocol)
  if not telemetrySensors then return end
  local adjFunction = telemetrySensors.getValue(protocol, "adj_f")
  if adjFunction ~= session.adjFunction then
    session.adjFunction = adjFunction
    publish()
  end

  local adjValue = telemetrySensors.getValue(protocol, "adj_v")
  if adjValue ~= session.adjValue then
    session.adjValue = adjValue
    publish()
  end
end

local function updateEscTemp(protocol)
  if not telemetrySensors then return end
  local value = telemetrySensors.getValue(protocol, "temp_esc")
  if value ~= session.tempEsc then
    session.tempEsc = value
    publish()
  end
end

local function updateMcuTemp(protocol)
  if not telemetrySensors then return end
  if protocol == "crsf" then return end

  local value = telemetrySensors.getValue(protocol, "temp_mcu")
  if value ~= session.tempMcu then
    session.tempMcu = value
    publish()
  end
end

local function updateBecVoltage(protocol)
  if not telemetrySensors then return end
  local value = telemetrySensors.getValue(protocol, "bec_voltage")
  if value ~= session.becVoltage then
    session.becVoltage = value
    publish()
  end
end

local function updateGovernor(protocol)
  if not telemetrySensors then return end
  local governorState = telemetrySensors.getValue(protocol, "governor")
  if governorState ~= session.governorState then
    session.governorState = governorState
    publish()
  end
end

local function updateFlightTimer(now)
  local changed, snapshot, event = flightTimer.update(session.connected, session.isArmed, now)
  if changed then
    session.timerLive = snapshot.timerLive
    session.timerSession = snapshot.timerSession
    session.timerFlightCounted = snapshot.timerFlightCounted
    publish()
  end

  if event and loadModelPreferences() then
    local stats = modelPreferences.stats(session.modelPreferences)
    if event.flightCounted then
      stats.flightcount = (tonumber(stats.flightcount) or 0) + 1
      session.modelPreferences = modelPreferences.setStats(session.modelPreferences, stats)
      saveModelPreferences()
    end
    if event.finishedSegment and event.finishedSegment > 0 then
      stats = modelPreferences.stats(session.modelPreferences)
      stats.lastflighttime = event.session or event.finishedSegment
      stats.totalflighttime = (tonumber(stats.totalflighttime) or 0) + event.finishedSegment
      session.modelPreferences = modelPreferences.setStats(session.modelPreferences, stats)
      saveModelPreferences()
      scheduleStatsSync(1)
    end
  end
end

local function onModelStatsUpdate(payload)
  if type(payload) ~= "table" or type(payload.stats) ~= "table" then return end
  if not session.mcuId or payload.mcuId ~= session.mcuId then return end
  loadModelPreferences()
  session.modelPreferences = modelPreferences.setStats(session.modelPreferences, payload.stats)
  saveModelPreferences()
  scheduleStatsSync(0)
end

bus.subscribe("model.stats.update", onModelStatsUpdate)

local function onModelTimerUpdate(payload)
  if type(payload) ~= "table" then return end
  if not session.mcuId or payload.mcuId ~= session.mcuId then return end
  loadModelPreferences()
  session.modelPreferences = modelPreferences.setTimerTarget(session.modelPreferences, payload.flighttime)
  saveModelPreferences()
end

bus.subscribe("model.timer.update", onModelTimerUpdate)

-- If the FC computes smartfuel itself (smartfuelMode > 0), just mirror its
-- broadcast sensor. Otherwise run the local sigmoid/slew estimator
-- (lib/smartfuel_calc.lua) against live voltage/consumption telemetry.
-- Either way the result gets the same "reserve" remap
-- (lib/smartfuel_reserve.lua) so 0% means "at the FC's configured warning
-- threshold", not "at absolute-empty".
--
-- Self-caught bug: the "Smart Fuel" DIY sensor used to only get pushed to
-- in the mode == 0 (local-calc) branch, on the assumption that mode > 0
-- meant a native sensor already existed for anyone else to read. That's
-- not how the original suite's own tasks/scheduler/sensors/smart.lua
-- works: it calls createOrUpdateSensor() for its "Smart Fuel" sensor
-- unconditionally every wakeup, regardless of mode -- mode only selects
-- which *input* feeds the value (mirror the FC's raw broadcast, or run
-- the local estimator), never whether the app's own labelled sensor gets
-- created. Matched that here: smartfuelSensor:set() now always runs, so
-- "Smart Fuel" shows up as a real sensor either way (mirroring
-- lib/diy_sensor.lua's own existing-sensor check means this is a no-op
-- write rather than a duplicate if something else also broadcasts at the
-- same appId).
local function updateFuel(protocol)
  if not telemetrySensors then return end
  if session.smartfuelMode == nil or not session.batteryConfig then
    return
  end

  local bc = session.batteryConfig
  local percent

  if session.smartfuelMode > 0 then
    local raw = telemetrySensors.getValue(protocol, "smartfuel")
    if raw then
      percent = smartfuelReserve.applyPercent(raw, bc.consumptionWarningPercentage)
    end
  else
    percent = localSmartFuel:update({
      voltage = telemetrySensors.getValue(protocol, "voltage"),
      consumption = telemetrySensors.getValue(protocol, "consumption"),
      cellCount = bc.cellCount,
      minV = bc.vbatMinCell,
      fullV = bc.vbatFullCell,
      packCapacity = bc.batteryCapacity,
      voltageFallPerSecond = session.smartfuelVoltageFallPerSecond,
      chargeDropPerSecond = session.smartfuelChargeDropPerSecond,
      warningPercent = bc.consumptionWarningPercentage,
    })
  end

  smartfuelSensor:set(percent, session.connected)

  if percent ~= session.fuelPercent then
    if session.fuelPercent == nil and percent ~= nil then
      debugLog.print("[session] fuelPercent now available: " .. tostring(percent) .. "% (mode=" .. tostring(session.smartfuelMode) .. ")")
    end
    session.fuelPercent = percent
    publish()
  end
end

local function wakeup(mspQueue, protocol, transport, simSensors)
  local now = os.clock()
  local telemetryActive = tlm and tlm:state()

  -- Ethos's own TELEMETRY_ACTIVE flag can flap in the simulator -- override
  -- it with the sensor editor's "Telemetry State" switch instead whenever
  -- one is available (tasks/background.lua only ever passes simSensors
  -- when isSim), matching that original suite's own tasks/tasks.lua
  -- comment calling out exactly this flapping.
  if isSim and simSensors then
    telemetryActive = simSensors.telemetryState()
  end

  if protocol ~= session.mspTransport then
    session.mspTransport = protocol
    publish()
  end

  if telemetryActive ~= session.connected then
    setConnected(telemetryActive == true, mspQueue, protocol)
  end

  -- Only affects which lib/telemetry_sensors.lua candidate table these
  -- lookups resolve against -- real transport-format gates below (the
  -- protocol == "crsf" check around ELRS custom-telemetry frame popping)
  -- keep using the real `protocol`, since that describes actual wire
  -- behaviour, not sensor-value lookup.
  local sensorProtocol = isSim and "sim" or protocol

  if SENSOR_CHECKS_ENABLED then
    if shouldRunScheduled("telemetry", TELEMETRY_VALUE_INTERVAL, now) then
      updateVoltage(sensorProtocol)
      updateRfStatusTelemetry(sensorProtocol)
      updateEscTemp(sensorProtocol)
      updateMcuTemp(sensorProtocol)
      updateBecVoltage(sensorProtocol)
      updateFuel(sensorProtocol)
    end

    if shouldRunScheduled("profiles", PROFILE_INTERVAL, now) then
      updateProfiles(sensorProtocol)
      updateGovernor(sensorProtocol)
    end

    if shouldRunScheduled("adjustment", ADJUSTMENT_INTERVAL, now) then
      updateAdjustment(sensorProtocol)
    end

    if shouldRunScheduled("blackbox", BLACKBOX_INTERVAL, now) then
      updateBlackboxSummary(mspQueue)
    end

    if protocol == "crsf" and session.connected and shouldRunScheduled("elrs", ELRS_SENSOR_INTERVAL, now) then
      ensureElrsSensors().wakeup(transport, session.telemetrySlots)
    end
  end

  updateFlightTimer(now)

  if pendingStatsSync and pendingStatsSyncAt and now >= pendingStatsSyncAt then
    pendingStatsSync = false
    pendingStatsSyncAt = nil
    syncStatsWithFc(mspQueue)
  end

end

local function setTelemetrySensors(instance)
  telemetrySensors = instance
end

return {wakeup = wakeup, setTelemetrySensors = setTelemetrySensors, setBatteryProfile = setBatteryProfile}
