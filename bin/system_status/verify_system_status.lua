-- Behaviour check for the packed FC status sensors (System Status / System
-- Config, firmware MSP API 12.10).
--
-- Run it:
--     lua5.4 bin/system_status/verify_system_status.lua
--     lua5.4 bin/system_status/verify_system_status.lua --self-test
--
-- What is pinned:
--   1. lib/system_status.lua decodes each field from the bit the firmware's
--      src/main/telemetry/status.h puts it in. A shifted field reads as a
--      different, plausible state (a governor in FALLBACK reads as AUTOROTATION),
--      so nothing on the radio would show it.
--   2. lib/system_alerts.lua: the banner shows the highest-priority active rule
--      plus a count, and the System Config rules (reboot required, Blackbox
--      full) still fire when the model sends System Config but not System
--      Status. The two are separate sensors and a pilot may select only one.
--   3. tasks/session.lua:
--      * a tick with no battery_profile reading keeps the last pack rather than
--        clearing session.batteryProfile, as the pid/rate profiles already did;
--      * a dropped system_status frame leaves session.isArmed alone;
--      * lib/system_status.lua is not loaded until one of the two words
--        arrives, so firmware before 12.10 never pays for it.
--   4. tasks/audio_events.lua: a callout rule records its starting state only
--      once the word it reads has arrived. With System Status first, a
--      Blackbox already full when System Config arrives must stay silent (the
--      banner shows it), and a later fill must still be announced.
--
-- session.lua is loaded with its Ethos globals and module loader stubbed, the
-- way bin/handshake_gate/verify_handshake_gate.lua does it. The codec, the
-- alert rules and lib/battery_profile_index.lua are the real files.
--
-- --self-test loads copies of the sources with each fix reverted and requires
-- the check pinning it to go red. A check that cannot fail proves nothing.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end

local ROOT = scriptDir() .. "/../.."
local SRC = ROOT .. "/src/rfsuite"
local SESSION_PATH = SRC .. "/tasks/session.lua"
local AUDIO_PATH = SRC .. "/tasks/audio_events.lua"
local ALERTS_PATH = SRC .. "/lib/system_alerts.lua"
local CODEC_PATH = SRC .. "/lib/system_status.lua"

local SELF_TEST = arg and arg[1] == "--self-test"

local failures = 0
local checks = 0

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

local function readFile(path)
  local f = assert(io.open(path, "rb"))
  local data = f:read("*a")
  f:close()
  return data
end

-- Replaces exactly one occurrence of `old`; errors if the source has moved on,
-- so a stale self-test mutation cannot silently become a no-op.
local function mutate(source, old, new)
  local first = source:find(old, 1, true)
  assert(first, "self-test mutation not found: " .. old)
  assert(not source:find(old, first + 1, true), "self-test mutation not unique: " .. old)
  return source:sub(1, first - 1) .. new .. source:sub(first + #old)
end

local function clearModules()
  package.loaded["rfsuite.lib.system_status"] = nil
  package.loaded["rfsuite.lib.system_alerts"] = nil
  package.loaded["rfsuite.lib.battery_profile_index"] = nil
end

-- Loader for the pure modules: the real files, with optional source overrides.
local function installPureLoader(overrides)
  overrides = overrides or {}
  package.loaded["rfsuite.lib.require"] = function(name)
    local path = SRC .. "/" .. name
    local source = overrides[name] or readFile(path)
    return assert(load(source, "@" .. path))()
  end
end

local function loadCodec()
  clearModules()
  installPureLoader()
  return assert(load(readFile(CODEC_PATH), "@" .. CODEC_PATH))()
end

local function loadAlerts(source)
  clearModules()
  installPureLoader()
  return assert(load(source or readFile(ALERTS_PATH), "@" .. ALERTS_PATH))()
end

-- ---------------------------------------------------------------------------
-- 1. Codec bit positions (firmware src/main/telemetry/status.h).
-- ---------------------------------------------------------------------------
local function codecChecks()
  local codec = loadCodec()

  -- One word with every flag set and each multi-bit field at a distinctive value.
  local statusWord = (1 << 0) | (1 << 1) | (1 << 2) | (1 << 3)
    | (codec.FAILSAFE.GPS_RESCUE << 6)
    | (codec.GPS_FIX.HOME << 9)
    | (1 << 11) | (1 << 12)
    | (codec.BATTERY.CRITICAL << 14)
    | (1 << 17) | (1 << 18) | (1 << 19) | (1 << 20)
    | (codec.RESCUE.HOVER << 21)
    | (1 << 24)
    | (codec.GOVERNOR.FALLBACK << 25)
  local s = codec.decodeStatus(statusWord)
  check("status flags decode from their bits",
    s.armed and s.airborne and s.motorsRunning and s.rxLinkUp and s.gpsHealthy
      and s.spooledUp and s.controlSaturated and s.gyroOverflow and s.accNotCalibrated
      and s.overrideActive and s.blackboxLogging)
  check("status fields decode from their bits",
    s.failsafePhase == codec.FAILSAFE.GPS_RESCUE and s.gpsFix == codec.GPS_FIX.HOME
      and s.batteryState == codec.BATTERY.CRITICAL and s.rescueState == codec.RESCUE.HOVER
      and s.governorState == codec.GOVERNOR.FALLBACK,
    string.format("failsafe=%s gps=%s battery=%s rescue=%s governor=%s",
      s.failsafePhase, s.gpsFix, s.batteryState, s.rescueState, s.governorState))

  local onlyArmed = codec.decodeStatus(1)
  check("a word with only bit 0 set is armed and nothing else",
    onlyArmed.armed and not onlyArmed.airborne and not onlyArmed.gyroOverflow
      and onlyArmed.governorState == 0 and onlyArmed.failsafePhase == 0)

  local configWord = 2 | (3 << 3) | (4 << 6)
    | (1 << 12) | (1 << 13) | (1 << 14) | (1 << 15) | (1 << 16) | (1 << 17)
    | (1 << 18) | (1 << 19) | (1 << 21) | (1 << 22)
    | (codec.GOVERNOR_MODE.NITRO << 23)
  local c = codec.decodeConfig(configWord)
  check("config profiles decode 1-based from their fields",
    c.pidProfile == 2 and c.rateProfile == 3 and c.batteryProfile == 4,
    string.format("pid=%s rate=%s battery=%s", c.pidProfile, c.rateProfile, c.batteryProfile))
  check("config flags and governor mode decode from their bits",
    c.configDirty and c.saving and c.rebootRequired and c.beeperOn and c.accPresent
      and c.baroPresent and c.magPresent and c.gpsPresent and c.blackboxFull
      and c.rpmSourceActive and c.governorMode == codec.GOVERNOR_MODE.NITRO)

  check("toRaw masks a sign-extended reading to 31 bits",
    codec.toRaw(-1) == 0x7FFFFFFF, tostring(codec.toRaw(-1)))
  check("a missing reading decodes to nil",
    codec.toRaw(nil) == nil and codec.decodeStatus(nil) == nil and codec.decodeConfig(nil) == nil)
end

-- ---------------------------------------------------------------------------
-- 2. Alert rules.
-- ---------------------------------------------------------------------------

-- The central measurement for the config-only case, reused by --self-test.
local function configOnlyBanner(alertsSource)
  local alerts = loadAlerts(alertsSource)
  local rule, count = alerts.topBanner(nil, { rebootRequired = true })
  return rule and rule.id, count
end

local function alertChecks()
  local alerts = loadAlerts()

  local rule, count = alerts.topBanner({ gyroOverflow = true, failsafePhase = 1, accNotCalibrated = true },
    { blackboxFull = true })
  check("the banner shows the highest-priority rule and counts every active one",
    rule and rule.id == "failsafe" and count == 4,
    "top=" .. tostring(rule and rule.id) .. " count=" .. tostring(count))
  check("a critical rule is critical", rule and rule.level == alerts.LEVEL.CRITICAL)

  rule, count = alerts.topBanner({ failsafePhase = 5 }, nil)
  check("RX_LOSS_RECOVERED is not a failsafe banner", rule == nil and count == 0,
    "top=" .. tostring(rule and rule.id))

  local id, n = configOnlyBanner()
  check("System Config alone still raises its own banner (reboot required)",
    id == "reboot_required" and n == 1, "top=" .. tostring(id) .. " count=" .. tostring(n))

  local blackbox
  for _, r in ipairs(alerts.RULES) do
    if r.id == "blackbox_full" then blackbox = r end
  end
  check("System Config alone still drives the Blackbox full callout",
    blackbox ~= nil and alerts.isActive(blackbox, nil, { blackboxFull = true }) == true)

  rule, count = alerts.topBanner(nil, nil)
  check("no words means no banner", rule == nil and count == 0)
end

-- ---------------------------------------------------------------------------
-- 3. session.lua rig.
-- ---------------------------------------------------------------------------

local clock = { now = 100.0, step = 0.001 }
os.clock = function()
  local t = clock.now
  clock.now = t + clock.step
  return t
end

local REAL = {
  ["lib/mspcodec.lua"] = true,
  ["lib/msp_api_version.lua"] = true,
  ["lib/msp_handshake.lua"] = true,
  ["lib/msp_battery.lua"] = true,
  ["lib/msp_governor_config.lua"] = true,
  ["lib/msp_rx_map.lua"] = true,
  ["lib/msp_telemetry_config.lua"] = true,
  ["lib/msp_dataflash_summary.lua"] = true,
  ["lib/msp_flight_stats.lua"] = true,
  ["lib/msp_eeprom.lua"] = true,
  ["lib/battery_profile_index.lua"] = true,
  ["lib/system_status.lua"] = true,
  ["tasks/flight_timer.lua"] = true,
}

local function newRig(source)
  clearModules()
  local published = {}
  local required = {}
  local values = {}
  local smartFuelResets = 0

  local realModules = {}
  package.loaded["rfsuite.lib.require"] = function(name)
    required[name] = true
    if REAL[name] then
      if realModules[name] == nil then
        realModules[name] = assert(loadfile(SRC .. "/" .. name))()
      end
      return realModules[name]
    elseif name == "lib/bus.lua" then
      return {
        publish = function(topic, payload) published[#published + 1] = { topic, payload } end,
        subscribe = function() end,
      }
    elseif name == "lib/debug_log.lua" then
      return { print = function() end, msp = function() end, format = function() end,
        mspEnabled = function() return false end }
    elseif name == "lib/settings_store.lua" then
      return {
        load = function() return {} end,
        simulatedApiVersionMode = function() return false end,
        syncNameEnabled = function() return false end,
      }
    elseif name == "lib/smartfuel_reserve.lua" then
      return { applyPercent = function() end }
    elseif name == "lib/smartfuel_calc.lua" then
      return { new = function() return { reset = function() smartFuelResets = smartFuelResets + 1 end } end }
    elseif name == "lib/diy_sensor.lua" then
      return { new = function() return { reset = function() end } end }
    elseif name == "lib/model_preferences.lua" then
      return {
        load = function() return {} end, save = function() end,
        setSmartfuelModelType = function() end, setStats = function() end,
        setTimerTarget = function() end,
        smartfuelModelType = function() return 0 end,
        stats = function() return {} end, timerTarget = function() return 300 end,
      }
    end
    return setmetatable({}, { __index = function()
      return function()
        return { command = 0, payload = {}, processReply = function() end, errorHandler = function() end }
      end
    end })
  end

  CATEGORY_SYSTEM_EVENT, TELEMETRY_ACTIVE = 2, 0
  SMARTFUEL_APP_ID, UNIT_PERCENT = 0x1A00, "%"
  system = {
    getVersion = function() return { simulation = false } end,
    getSource = function() return { state = function() return true end } end,
    playFile = function() end,
    playHaptic = function() end,
  }
  model = { name = function() return "Test" end, set = function() end }

  local session = assert(load(source or readFile(SESSION_PATH), "@" .. SESSION_PATH))()
  session.setTelemetrySensors({
    getValue = function(_, name) return values[name] end,
    reset = function() end,
  })
  local queue = { add = function() return true end, clear = function() end }

  local rig = { values = values, required = required }
  -- One tick, past the 0.5s profile cadence so updateProfiles() runs too.
  function rig.tick()
    clock.now = clock.now + 0.6
    session.wakeup(queue, "sport", nil, nil)
  end
  function rig.snapshot()
    for i = #published, 1, -1 do
      if published[i][1] == "session.update" then return published[i][2] end
    end
    return {}
  end
  function rig.smartFuelResets() return smartFuelResets end
  return rig
end

-- Battery profile across a missed reading. Returns the profile seen after the
-- gap, and whether it was ever cleared on the way.
local function batteryProfileAcrossGap(source)
  local rig = newRig(source)
  rig.values.battery_profile = 3
  rig.tick()
  local before = rig.snapshot().batteryProfile
  rig.values.battery_profile = nil
  rig.tick()
  local during = rig.snapshot().batteryProfile
  rig.values.battery_profile = 3
  rig.tick()
  return before, during, rig.snapshot().batteryProfile
end

local function codecLoadedWithoutWords(source)
  local rig = newRig(source)
  rig.values.armflags = 0
  rig.values.pid_profile = 1
  rig.tick()
  rig.tick()
  return rig.required["lib/system_status.lua"] == true
end

local function sessionChecks()
  local before, during, after = batteryProfileAcrossGap()
  check("battery_profile 3 reads as the 0-based pack 2", before == 2, tostring(before))
  check("a tick with no battery_profile reading keeps the last pack",
    during == 2 and after == 2,
    "before=" .. tostring(before) .. " during=" .. tostring(during) .. " after=" .. tostring(after))

  do
    local rig = newRig()
    rig.values.system_config = 2 | (2 << 3) | (5 << 6)
    rig.tick()
    local snap = rig.snapshot()
    check("profiles come from system_config when it is sent",
      snap.pidProfile == 2 and snap.rateProfile == 2 and snap.batteryProfile == 4,
      string.format("pid=%s rate=%s battery=%s", snap.pidProfile, snap.rateProfile, snap.batteryProfile))
    -- A config word with no battery profile (field 0) is not a valid 1-based
    -- reading either: it must not clear the pack.
    rig.values.system_config = 2 | (2 << 3)
    rig.tick()
    check("a system_config battery field of 0 keeps the last pack",
      rig.snapshot().batteryProfile == 4, tostring(rig.snapshot().batteryProfile))
  end

  do
    local rig = newRig()
    rig.values.system_status = 1
    rig.tick()
    check("the ARMED bit of system_status arms the session", rig.snapshot().isArmed == true)
    rig.values.system_status = nil
    rig.tick()
    check("a dropped system_status frame leaves the session armed", rig.snapshot().isArmed == true,
      tostring(rig.snapshot().isArmed))
    rig.values.system_status = 0
    rig.tick()
    check("the next frame disarms it", rig.snapshot().isArmed == false)
  end

  do
    local rig = newRig()
    rig.values.system_status = 0
    rig.values.armflags = 1
    rig.tick()
    check("system_status wins over the armflags sensor when both are sent",
      rig.snapshot().isArmed == false)
  end

  check("lib/system_status.lua is not loaded when neither packed word is sent",
    codecLoadedWithoutWords() == false)
  do
    local rig = newRig()
    rig.values.system_config = 1
    rig.tick()
    check("lib/system_status.lua is loaded once a packed word arrives",
      rig.required["lib/system_status.lua"] == true)
  end
end

-- ---------------------------------------------------------------------------
-- 4. audio_events.lua callouts.
-- ---------------------------------------------------------------------------

-- The real audio_events.lua with the real alert rules; the bus, settings and
-- Ethos audio calls are stubbed. Returns a driver that publishes a session
-- snapshot, runs one wakeup and reports the files played.
local function newAudioRig(source, alertsSource)
  clearModules()
  local onSession
  local played = {}
  package.loaded["rfsuite.lib.require"] = function(name)
    if name == "lib/bus.lua" then
      return { publish = function() end,
        subscribe = function(topic, fn) if topic == "session.update" then onSession = fn end end }
    elseif name == "lib/settings_store.lua" then
      return {
        load = function() return {} end,
        audioEvents = function() return { status_blackbox = true, status_gyro = true, status_gps = true } end,
        audioTimer = function() return {} end,
      }
    elseif name == "lib/engine_type.lua" then
      return { isElectric = function() return true end }
    elseif name == "lib/system_alerts.lua" and alertsSource then
      return assert(load(alertsSource, "@" .. ALERTS_PATH))()
    end
    return assert(loadfile(SRC .. "/" .. name))()
  end
  system = {
    playFile = function(path) played[#played + 1] = path end,
    playNumber = function() end,
    playHaptic = function() end,
    playTone = function() end,
    getAudioVoice = function() return "en/default" end,
  }
  local audio = assert(load(source or readFile(AUDIO_PATH), "@" .. AUDIO_PATH))()

  local rig = {}
  function rig.step(status, config)
    onSession({ connected = true, systemStatus = status, systemConfig = config })
    audio.wakeup()
  end
  function rig.count(file)
    local n = 0
    for _, path in ipairs(played) do
      if path:sub(-#file) == file then n = n + 1 end
    end
    return n
  end
  return rig
end

-- Status first, then a config word that already reports a full Blackbox.
-- Returns how many times bbfull.wav played on that first config word.
local function blackboxAnnouncedOnArrival(source)
  local rig = newAudioRig(source)
  local status = { raw = 0 }
  rig.step(status, nil)
  rig.step(status, nil)
  rig.step(status, nil)
  rig.step(status, { raw = 1, blackboxFull = true })
  rig.step(status, { raw = 1, blackboxFull = true })
  return rig.count("bbfull.wav"), rig
end

local function calloutChecks()
  local count, rig = blackboxAnnouncedOnArrival()
  check("a Blackbox already full when System Config arrives after System Status is not announced",
    count == 0, "bbfull.wav played " .. count .. "x")
  local status = { raw = 0 }
  rig.step(status, { raw = 2, blackboxFull = false })
  rig.step(status, { raw = 1, blackboxFull = true })
  check("a Blackbox that fills later is announced", rig.count("bbfull.wav") == 1,
    "bbfull.wav played " .. rig.count("bbfull.wav") .. "x")

  local cfgFirst = newAudioRig()
  cfgFirst.step(nil, { raw = 2, blackboxFull = false })
  cfgFirst.step(nil, { raw = 2, blackboxFull = false })
  cfgFirst.step(nil, { raw = 2, blackboxFull = false })
  cfgFirst.step(nil, { raw = 1, blackboxFull = true })
  check("with System Config alone, a Blackbox that fills is announced",
    cfgFirst.count("bbfull.wav") == 1, "bbfull.wav played " .. cfgFirst.count("bbfull.wav") .. "x")
end

-- ---------------------------------------------------------------------------
-- Self-test: each fix reverted must turn its check red.
-- ---------------------------------------------------------------------------
local function selfTest()
  local session = readFile(SESSION_PATH)
  local alerts = readFile(ALERTS_PATH)

  local noGuard = mutate(session,
    "if batteryProfile ~= nil and batteryProfile ~= session.batteryProfile then",
    "if batteryProfile ~= session.batteryProfile then")
  local _, during = batteryProfileAcrossGap(noGuard)
  check("self-test: without the nil guard the pack is cleared on a missed reading",
    during == nil, "during=" .. tostring(during))

  local statusOnly = mutate(alerts,
    "if status == nil and config == nil then return nil, 0 end",
    "if status == nil then return nil, 0 end")
  local id = configOnlyBanner(statusOnly)
  check("self-test: gating topBanner() on System Status hides the config-only banner",
    id == nil, "top=" .. tostring(id))

  local eager = mutate(session,
    "local systemStatusCodec = nil",
    'local systemStatusCodec = requireModule("lib/system_status.lua")')
  check("self-test: an eager require loads the codec without either word",
    codecLoadedWithoutWords(eager) == true)

  local noWait = mutate(readFile(AUDIO_PATH),
    "if rule.enterSound and systemAlerts.hasWords(rule, status, config) then",
    "if rule.enterSound then")
  local count = blackboxAnnouncedOnArrival(noWait)
  check("self-test: without waiting for the word, the existing full Blackbox is announced",
    count == 1, "bbfull.wav played " .. count .. "x")
end

if SELF_TEST then
  print("system status self-test")
  selfTest()
else
  print("system status codec")
  codecChecks()
  print("system status alerts")
  alertChecks()
  print("system status session")
  sessionChecks()
  print("system status callouts")
  calloutChecks()
end

print(string.format("%d/%d checks passed", checks - failures, checks))
if failures > 0 then os.exit(1) end
