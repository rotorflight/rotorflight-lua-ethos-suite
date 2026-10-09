-- Lightweight session-driven audio events.

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local bus = requireModule("lib/bus.lua")
local batteryProfileIndex = requireModule("lib/battery_profile_index.lua")
local engineType = requireModule("lib/engine_type.lua")
local settingsStore = requireModule("lib/settings_store.lua")

local audio_events = {}

local settings = nil
local events = nil
local timer = nil
local session = {}
local previous = {}
local initialized = false
local adjWavs = nil

local lastAlertAt = {}
-- Whether the pack has read a real voltage at any point in the current run.
-- The main-power test below needs it: a model whose pack is not measured at
-- all would otherwise look exactly like one whose pack has gone.
local packVoltageSeen = false
-- True between a main-power alert actually playing and the pack coming back,
-- so the recovery is only announced for an episode that was announced lost.
local mainPowerLostActive = false
-- When the pack first read below the warning cell voltage in the current
-- run, for the hold filter in announceVoltage(). nil while the reading is
-- at or above the threshold (or before a first below-threshold reading).
local lowVoltageHoldStart = nil
-- The moment a telemetry loss that was announced happened, or nil while nothing
-- is outstanding. This is what gates the recovery on the *initial* loss rather
-- than on the link being back: a model that comes back is told it recovered
-- only if it was told it was lost, and only while that loss still belongs to
-- this flight (issue #2311).
local connectionLostAt = nil
-- lib/system_alerts.lua, loaded once the FC's system_status or system_config
-- first arrives (firmware before MSP API 12.10 sends neither).
local systemAlerts = nil
-- lib/system_alerts.lua rule id -> {reported, pending, since}: the state last
-- announced, and a change waiting out the rule's debounce.
local alertState = {}
-- Minimum gap between "control limit" callouts while the controls keep
-- hitting their limit.
local CONTROL_LIMIT_REPEAT_SECONDS = 3
-- What separates "the pack is gone" from "the pack is low". A disconnected
-- main battery reads as no voltage at all, and the lowest a flight pack is
-- ever taken to is far above this, so nothing a discharge can reach falls
-- inside the window. The same number and the same test the EdgeTX suite's
-- lib/audio.lua uses (MAIN_POWER_LOST_VOLTS, Audio.mainPowerLost).
local MAIN_POWER_LOST_VOLTS = 1.0
-- How often a main-power alert repeats while the pack stays gone.
local MAIN_POWER_REPEAT_SECONDS = 10
-- The sound each main-power announcement would like the sound packs to gain,
-- with the files every shipped pack already carries as the fallback. The
-- EdgeTX suite does the same, for the same reason: every shipped file names a
-- different event, so a pack without the dedicated word says the nearest one
-- rather than nothing. (pkg, file) in play order; resolved once per
-- announcement by firstResolvedSound().
local MAIN_POWER_LOST_SOUNDS = {
  {"status", "alerts/mainpower.wav"},
  {"status", "alerts/lowbat.wav"},
  {"status", "alerts/lowvoltage.wav"},
}
local MAIN_POWER_OK_SOUNDS = {
  {"status", "alerts/mainpowerok.wav"},
  {"events", "alerts/battery.wav"},
}
-- How long a telemetry loss stays eligible for a recovery announcement. Past
-- it the pending flag is dropped without a word: a model that answers again a
-- quarter of an hour later is a new flight, and "telemetry recovered" belongs
-- to the one that was interrupted. The same window and the same reasoning as
-- the EdgeTX suite's lib/audio.lua (CONNECTION_RECOVERY_WINDOW). It is
-- deliberately not tasks/flight_timer.lua's RECONNECT_GRACE_SECONDS, which
-- decides whether two records are one flight and answers a different question.
local CONNECTION_RECOVERY_WINDOW = 120
-- The word each half of the announcement would like the sound packs to gain.
-- No pack carries either one yet, and neither has a neighbour worth borrowing:
-- every shipped alert names a different event, and saying a lost link in the
-- words of an empty battery is worse than saying nothing -- the same reasoning
-- the EdgeTX suite's lib/audio.lua gives for its own two connection sounds
-- (CONNECTION_LOST_SOUND, CONNECTION_OK_SOUND). So the haptic in
-- announceTelemetryLost()/announceTelemetryRecovered() is what the pilot gets
-- today and the file is what he gets once a pack carries it.
local TELEMETRY_LOST_SOUNDS = {
  {"events", "alerts/telemetrylost.wav"},
}
local TELEMETRY_OK_SOUNDS = {
  {"events", "alerts/telemetryok.wav"},
}
local craftNameAnnounced = false
local lastSmartfuelAnnounced = nil
-- Whether a numeric fuel reading has been evaluated yet, as opposed to merely
-- being present. See announceSmartfuel() for why the two are not the same thing.
local fuelEvaluated = false
local lastLowFuelAnnounced = false
local lastLowFuelRepeatAt = 0
local lastLowFuelRepeatCount = 0
local pendingAdjFunction = false
-- When the adjustment last moved without having been spoken yet, or nil while
-- nothing is waiting. See announceAdjustment().
local adjChangedAt = nil
-- How long an in-flight adjustment has to stand still before it is spoken
-- (issue #2315). The flight controller steps a held trim switch every 200 ms
-- (rotorflight-firmware src/main/fc/rc_adjustments.c, REPEAT_DELAY), so a
-- window above that is what turns a burst of clicks into one announcement.
local ADJ_SETTLE_SECONDS = 0.35
local speakingUntil = 0
local rollingSamples = {}
local timerTriggered = false
local timerLastBeep = nil
local timerPreLastBeep = nil

local SPEAK_WAV_SECONDS = 0.45
local SPEAK_NUM_SECONDS = 0.6

local GOVERNOR_FILES = {
  [0] = "off.wav",
  [1] = "idle.wav",
  [2] = "spoolup.wav",
  [3] = "recovery.wav",
  [4] = "active.wav",
  [5] = "thr-off.wav",
  [6] = "lost-hs.wav",
  [7] = "autorot.wav",
  [8] = "bailout.wav",
  [100] = "disabled.wav",
  [101] = "disarmed.wav",
}

local SMARTFUEL_THRESHOLDS = {
  [0] = {100, 10},
  [5] = {50, 5},
  [10] = {100, 90, 80, 70, 60, 50, 40, 30, 20, 10},
  [20] = {100, 80, 60, 40, 20, 10},
  [25] = {100, 75, 50, 25, 10},
  [50] = {100, 50, 10},
}

local AUDIO_SESSION_KEYS = {
  "connected",
  "craftName",
  "isArmed",
  "pidProfile",
  "rateProfile",
  "batteryProfile",
  "governorMode",
  "governorState",
  "systemStatus",
  "systemConfig",
  "voltage",
  "batteryConfig",
  "tempEsc",
  "becVoltage",
  "fuelPercent",
  "adjFunction",
  "adjValue",
  "timerLive",
  "timerTarget",
  "smartfuelModelType",
}

local function fileExists(path)
  local file = io.open(path, "r")
  if not file then return false end
  file:close()
  return true
end

local function audioVoice()
  local voice = nil
  if system.getAudioVoice then voice = system.getAudioVoice() end
  voice = tostring(voice or "en/default")
  voice = voice:gsub("SD:", ""):gsub("RADIO:", ""):gsub("AUDIO:", ""):gsub("VOICE[1-4]:", ""):gsub("audio/", "")
  if voice:sub(1, 1) == "/" then voice = voice:sub(2) end
  if voice == "" then voice = "en/default" end
  return voice
end

local function playFile(pkg, file)
  local user = "SCRIPTS:/rfsuite.user/audio/user/" .. pkg .. "/" .. file
  local locale = "SCRIPTS:/rfsuite/audio/" .. audioVoice() .. "/" .. pkg .. "/" .. file
  local fallback = "SCRIPTS:/rfsuite/audio/en/default/" .. pkg .. "/" .. file
  if fileExists(user) then
    system.playFile(user)
  elseif fileExists(locale) then
    system.playFile(locale)
  else
    system.playFile(fallback)
  end
end

local function playCommon(file)
  system.playFile("audio/" .. file)
end

local function playAlert(file)
  playFile("events", "alerts/" .. file)
end

local function playStatus(file)
  playFile("status", "alerts/" .. file)
end

local function playGovernor(file)
  playFile("events", "gov/" .. file)
end

local function playAdjFunctionToken(file)
  playFile("adjfunctions", file)
end

local function playNumber(value, unit, decimals)
  if system.playNumber then system.playNumber(value, unit, decimals) end
end

-- The path a packaged sound would play from, in the same user -> locale ->
-- en/default order playFile() uses, but returning nil when none of them is
-- there. playFile() itself is left alone: it plays the en/default path for
-- any built-in file, and every one of those ships. This is only for the
-- main-power sounds above, which a pack may not carry yet.
local function resolveSound(pkg, file)
  local user = "SCRIPTS:/rfsuite.user/audio/user/" .. pkg .. "/" .. file
  if fileExists(user) then return user end
  local locale = "SCRIPTS:/rfsuite/audio/" .. audioVoice() .. "/" .. pkg .. "/" .. file
  if fileExists(locale) then return locale end
  local fallback = "SCRIPTS:/rfsuite/audio/en/default/" .. pkg .. "/" .. file
  if fileExists(fallback) then return fallback end
  return nil
end

local function firstResolvedSound(candidates)
  for i = 1, #candidates do
    local path = resolveSound(candidates[i][1], candidates[i][2])
    if path then return path end
  end
  return nil
end

local function haptic()
  if system.playHaptic then system.playHaptic(". . . .") end
end

local function canSpeak(now)
  return now >= speakingUntil
end

local function markSpoken(now, duration)
  local untilAt = now + duration
  if untilAt > speakingUntil then speakingUntil = untilAt end
end

local function updateRollingAverage(key, value, window)
  local state = rollingSamples[key]
  if not state or state.window ~= window then
    state = {values = {}, next = 1, count = 0, sum = 0, window = window}
    rollingSamples[key] = state
  end

  local index = state.next
  if state.count == window then
    state.sum = state.sum - (state.values[index] or 0)
  else
    state.count = state.count + 1
  end
  state.values[index] = value
  state.sum = state.sum + value

  index = index + 1
  if index > window then index = 1 end
  state.next = index

  return state.sum / state.count
end

local function copySnapshot(snapshot)
  for key in pairs(session) do session[key] = nil end
  snapshot = snapshot or {}
  for i = 1, #AUDIO_SESSION_KEYS do
    local key = AUDIO_SESSION_KEYS[i]
    session[key] = snapshot[key]
  end
end

local function onSessionUpdate(snapshot)
  copySnapshot(snapshot)
end

-- Which word the fuel/battery percentage and low-fuel callouts use depends on
-- the powerplant. The flight controller reports no model type at all
-- (MSP_SMARTFUEL_CONFIG is four bytes -- mode, voltage fall, charge drop, sag
-- gain) and has no tank/fuel concept, so the only sources are the
-- transmitter-side model preference (app/pages/power_smartfuel.lua's
-- MODEL_TYPE_CHOICES, published in session.smartfuelModelType) and the configured
-- battery config. Auto is *resolved* from the config, not guessed: a cell count
-- or a configured pack capacity means a battery. Same rule as
-- widgets/dashboard/context.lua's isElectricEngine(), both now reading lib/engine_type.lua.
local function isElectricModel()
  return engineType.isElectric(session.batteryConfig, session.smartfuelModelType)
end

-- The percentage callout's word, and whether it lives in the events package.
-- There is no status/alerts/battery.wav in any locale, but
-- events/alerts/battery.wav is the same word ("Battery" / "Akku") in every
-- sound pack, and playFile() only treats the package as a path segment, so it
-- is read from there.
local function percentCalloutAlert()
  if isElectricModel() then return "battery.wav", true end
  return "fuel.wav", false
end

-- status/alerts/lowbat.wav ("Battery empty" / "Akku leer") ships in every
-- sound pack but was wired to nothing before this change.
local function lowCalloutAlert()
  if isElectricModel() then return "lowbat.wav" end
  return "lowfuel.wav"
end

-- One dispatch point for a callout word, so the selectors above only decide
-- which file and package. At module scope, not inside the announcement: that
-- runs on the announcement timer and a per-call closure would be churn on
-- every tick.
local function playCalloutAlert(file, fromEvents)
  if fromEvents then
    playAlert(file)
  else
    playStatus(file)
  end
end

local function onSettingsUpdate(snapshot)
  settings = snapshot or {}
  events = settingsStore.audioEvents(settings)
  timer = settingsStore.audioTimer(settings)
  if events.adj_f ~= true then adjWavs = nil end
end

bus.subscribe("session.update", onSessionUpdate)
bus.subscribe("settings.update", onSettingsUpdate)

local function ensureSettings()
  if not settings then
    settings = settingsStore.load()
  end
  if not events then
    events = settingsStore.audioEvents(settings)
  end
  if not timer then
    timer = settingsStore.audioTimer(settings)
  end
end

-- Plays a pilot-recorded "/audio/<craft name>.wav" once per connect, if
-- one exists -- matches the original suite's own postconnect
-- announceCraftname.lua. Checked every wakeup (not just the first tick
-- after connecting) since session.craftName arrives asynchronously from
-- its own MSP read and may not be known yet on that first tick;
-- craftNameAnnounced latches true the first time both the setting is on
-- and the name is known, so this only ever plays (or gives up trying)
-- once per connection.
local function announceCraftName()
  if craftNameAnnounced then return end
  if not events.craft_name then return end
  local craftName = session.craftName
  if not craftName or craftName == "" then return end

  craftNameAnnounced = true
  local candidates = {
    "/audio/" .. craftName .. ".wav",
    "/audio/" .. craftName:gsub(" ", "_") .. ".wav",
  }
  for i = 1, #candidates do
    if fileExists(candidates[i]) then
      system.playFile(candidates[i])
      return
    end
  end
end

local function announceArmed()
  if not events.armflags then return end
  if previous.isArmed == nil or session.isArmed == nil then return end
  if previous.isArmed == session.isArmed then return end
  playAlert(session.isArmed and "armed.wav" or "disarmed.wav")
end

local function announceProfile(key, enabled, file)
  if not enabled then return end
  local value = tonumber(session[key])
  local last = tonumber(previous[key])
  if value == nil or last == nil or value == last then return end
  playAlert(file)
  playNumber(math.floor(value))
end

local function extractCapacityValue(value)
  if type(value) == "number" then return value end
  if type(value) == "string" then return tonumber(value:match("(%d+)")) end
  if type(value) == "table" then
    if type(value.capacity) == "number" then return value.capacity end
    if type(value.capacity) == "string" then return tonumber(value.capacity:match("(%d+)")) end
    if type(value.name) == "string" then return tonumber(value.name:match("(%d+)")) end
  end
  return nil
end

local function batteryProfileCapacity(profile)
  local profiles = session.batteryConfig and session.batteryConfig.profiles
  if type(profiles) ~= "table" then return nil end
  -- No `profiles[profile + 1]` retry: session.batteryConfig.profiles is
  -- indexed 0..5, straight from the MSP_BATTERY_CONFIG reply
  -- (lib/msp_battery.lua decodes batteryCapacity[0..5]; the firmware writes
  -- them in that order, rotorflight-firmware src/main/msp/msp.c:906-908).
  -- The old retry existed only to paper over an off-by-one one layer up, and
  -- stood ready to answer with a neighbouring pack's capacity.
  local value = profiles[profile]
  value = extractCapacityValue(value)
  if value and value > 0 then return value end
  return nil
end

local function batteryProfileCellCount(profile)
  local config = session.batteryConfig
  if type(config) ~= "table" then return nil end

  local profileCells = config.profileCells
  if type(profileCells) == "table" and profile ~= nil then
    local cells = profileCells[profile]
    if type(cells) == "table" then
      cells = cells.cellCount
    end
    cells = tonumber(cells)
    if cells and cells > 0 then return cells end
  end

  local cells = tonumber(config.cellCount)
  if cells and cells > 0 then return cells end
  return nil
end

local function announceBatteryProfile()
  if not events.battery_profile then return end
  -- session.batteryProfile and the previous.batteryProfile snapshot are both
  -- already the internal 0-based index (tasks/session.lua converts the FC's
  -- 1-based `battery_profile` telemetry sensor once, at its ingress point).
  -- Validating is right; re-basing is not -- it made the announcement name
  -- the pack one below the one actually selected, and made a real 1 -> 2
  -- change look like "no change" and go unspoken.
  local value = batteryProfileIndex.index0(session.batteryProfile)
  local last = batteryProfileIndex.index0(previous.batteryProfile)
  if value == nil or last == nil or value == last then return end

  local capacity = batteryProfileCapacity(value)
  if not capacity then return end
  local cells = batteryProfileCellCount(value)

  playAlert("battery.wav")
  playNumber(math.floor(capacity + 0.5), UNIT_MILLIAMPERE_HOUR)
  -- Ethos has no spoken unit for cells (UNIT_CELLS is not a playNumber
  -- unit), so say the number bare and follow it with our own word.
  if cells then
    playNumber(math.floor(cells + 0.5))
    playAlert("cells.wav")
  end
end

local function announceGovernor()
  if not events.governor then return end
  if session.connected ~= true or session.isArmed ~= true then return end
  local mode = tonumber(session.governorMode)
  if mode == nil or mode == 0 then return end

  local value = tonumber(session.governorState)
  local last = tonumber(previous.governorState)
  if value == nil or last == nil or value == last then return end
  local file = GOVERNOR_FILES[math.floor(value)]
  if file then playGovernor(file) end
end

local function ensureAdjWavs()
  if not adjWavs then adjWavs = requireModule("tasks/adjfunctions/wavs.lua") end
  return adjWavs
end

local function speakAdjFunction(adjFunction, now)
  local spec = ensureAdjWavs()[adjFunction]
  if type(spec) ~= "string" then return nil end

  local count = 0
  for token in spec:gmatch("[^%s]+") do
    playAdjFunctionToken(token .. ".wav")
    count = count + 1
  end
  if count == 0 then return false end
  markSpoken(now, SPEAK_WAV_SECONDS * count)
  return true
end

local function speakAdjValue(value, now)
  if value == nil then return end
  playNumber(math.floor(value))
  markSpoken(now, SPEAK_NUM_SECONDS)
end

local function announceVoltage(now)
  if not events.voltage then
    lastAlertAt.voltage = nil
    lowVoltageHoldStart = nil
    return
  end
  if session.connected ~= true then
    lowVoltageHoldStart = nil
    return
  end

  local voltage = tonumber(session.voltage)
  local config = session.batteryConfig
  local cellCount = tonumber(config and config.cellCount)
  local warnCell = tonumber(config and config.vbatWarningCell)
  if voltage == nil or cellCount == nil or cellCount <= 0 or warnCell == nil or warnCell <= 0 then
    lowVoltageHoldStart = nil
    return
  end

  -- Below 1V total is implausible for a connected battery (e.g. running on
  -- USB power alone with no pack attached) -- don't let a near-zero noise
  -- reading trigger the low-voltage alarm.
  if voltage < 1 then
    lastAlertAt.voltage = nil
    lowVoltageHoldStart = nil
    return
  end

  local cellVoltage = voltage / cellCount
  if cellVoltage >= warnCell then
    lastAlertAt.voltage = nil
    lowVoltageHoldStart = nil
    return
  end

  -- Voltage sag: an aggressive 3D maneuver pulls the pack below the warning
  -- cell voltage for a fraction of a second and it recovers immediately.
  -- The alarm only fires once the reading has stayed below the threshold for
  -- events.voltage_hold seconds, so a transient dip is not called out
  -- (issue #2309). 0 disables the filter and fires on the first low reading.
  local hold = tonumber(events.voltage_hold)
  if hold == nil then hold = 2.0 end
  if not lowVoltageHoldStart then lowVoltageHoldStart = now end
  if (now - lowVoltageHoldStart) < hold then return end

  local repeatInterval = tonumber(events.voltage_repeat_interval) or 10
  if lastAlertAt.voltage and (now - lastAlertAt.voltage) < repeatInterval then return end
  lastAlertAt.voltage = now
  playAlert("lowvoltage.wav")

  -- Speak the reading itself if configured (issue #2309): the pack total at
  -- one decimal (e.g. "22.4 volts") or the average cell at two (e.g. "3.65
  -- volts"). playNumber() takes the value scaled to the decimals it is asked
  -- to speak, so the total is sent as tenths and the cell as hundredths.
  -- 0 (default) keeps the old alert-only callout.
  local callout = tonumber(events.voltage_callout) or 0
  if callout == 1 then
    playNumber(math.floor((voltage * 10) + 0.5), UNIT_VOLT, 1)
  elseif callout == 2 then
    playNumber(math.floor((cellVoltage * 100) + 0.5), UNIT_VOLT, 2)
  end
end

-- The main pack is gone while the flight controller stays alive on a BEC or a
-- backup battery. Telemetry can report this at all only because everything
-- else keeps arriving: the receiver and the FC are on the reserve, and the
-- pack voltage is the one sensor with nothing behind it. Nothing else in this
-- file would notice the machine is flying on its backup.
--
-- Three things have to be true together, and the second is what keeps a model
-- whose pack is not measured at all quiet: the pack reads as gone rather than
-- merely low, it has read a real voltage at some point this connection, and a
-- BEC voltage is there beside it -- without one there is no evidence anything
-- is still powered. The same test as the EdgeTX suite's lib/audio.lua
-- (Audio.mainPowerLost); decoding "gone" as total voltage rather than per
-- cell is the other half of why this is its own function and not a branch of
-- announceVoltage(). Not armed-gated, for the same reason it is not there:
-- the pack-seen latch already keeps a bench setup with no pack attached quiet,
-- and a pack that goes while the model sits on the ground is still a fault.
local function mainPowerLost()
  local voltage = tonumber(session.voltage)
  if voltage == nil then return false end

  if voltage > MAIN_POWER_LOST_VOLTS then
    packVoltageSeen = true
    return false
  end

  if not packVoltageSeen then return false end

  local bec = tonumber(session.becVoltage)
  if bec == nil or bec <= 0 then return false end

  return true
end

-- Announced again every MAIN_POWER_REPEAT_SECONDS while the pack stays gone,
-- and once more when it comes back. The BEC voltage and not the pack's is
-- spoken on the way in: it is the reading that still means something, and it
-- says how much is left of whatever is keeping the receiver alive.
local function announceMainPowerLost(now)
  if not events.main_power_lost then
    -- Forget an episode the pilot switched the alert off in, so switching it
    -- back on does not announce a recovery for a loss that was never spoken.
    mainPowerLostActive = false
    return
  end
  if session.connected ~= true then return end

  local voltage = tonumber(session.voltage)
  if voltage == nil then return end

  if not mainPowerLost() then
    if voltage > MAIN_POWER_LOST_VOLTS and mainPowerLostActive then
      mainPowerLostActive = false
      lastAlertAt.main_power = nil
      -- The voice goes out whether or not a sound file resolves, the same as
      -- on the way in below.
      local path = firstResolvedSound(MAIN_POWER_OK_SOUNDS)
      if path then system.playFile(path) end
      playNumber(math.floor((voltage * 10) + 0.5), UNIT_VOLT, 1)
    end
    return
  end

  if lastAlertAt.main_power and (now - lastAlertAt.main_power) < MAIN_POWER_REPEAT_SECONDS then return end
  -- The voice and the haptic go out whether or not a sound file resolves: a
  -- pack that carries none of the loss sounds would otherwise get no alert at
  -- all, and the spoken BEC voltage is the part that says how long is left.
  local path = firstResolvedSound(MAIN_POWER_LOST_SOUNDS)
  lastAlertAt.main_power = now
  mainPowerLostActive = true
  if path then system.playFile(path) end
  local bec = tonumber(session.becVoltage)
  if bec then playNumber(math.floor((bec * 10) + 0.5), UNIT_VOLT, 1) end
  haptic()
end

-- The flight controller link went away. Announced once per loss, and only when
-- the model was armed in the tick before it went: unplugging the pack on the
-- bench, or powering down after landing, is the normal end of a session and
-- says nothing, while the same drop with the rotors turning is the one event a
-- pilot must not have to notice for himself (issue #2311).
--
-- The armed state is read from `previous`, not from `session`: the session
-- clears isArmed in the same step that clears connected (tasks/session.lua's
-- setConnected()), so by the time a down link is visible here the armed state
-- is already gone -- and rememberCurrent() overwrites `previous` with that
-- empty value at the end of the branch wakeup() calls this from, which is why
-- this runs before it.
local function announceTelemetryLost(now)
  if not events.telemetry_lost then return end
  if previous.isArmed ~= true then return end

  connectionLostAt = now
  local path = firstResolvedSound(TELEMETRY_LOST_SOUNDS)
  if path then system.playFile(path) end
  -- Out whether or not a file resolves, for the same reason as the main-power
  -- alert above: a pack that carries none of the words would otherwise get no
  -- alert at all, and a lost link while armed is not something to leave to a
  -- file the pack happens to ship.
  haptic()
end

-- The model answering again, once, and only for a loss that was announced.
--
-- The setting is not re-read here on purpose: the flag is only ever set by a
-- loss that was announced, so a pilot who never switched the alert on hears
-- neither half, and one who switches it off mid-episode still hears the end of
-- the episode he was told about.
local function announceTelemetryRecovered(now)
  if not connectionLostAt then return end
  local since = now - connectionLostAt
  connectionLostAt = nil
  if since > CONNECTION_RECOVERY_WINDOW then return end

  local path = firstResolvedSound(TELEMETRY_OK_SOUNDS)
  if path then system.playFile(path) end
  haptic()
end

local function announceEscTemp(now)
  if not events.temp_esc then return end
  if session.connected ~= true then return end

  local temp = tonumber(session.tempEsc)
  if temp == nil then return end
  local threshold = tonumber(events.escalertvalue) or 90
  local avgTemp = updateRollingAverage("temp_esc", temp, 5)
  if avgTemp < threshold then
    lastAlertAt.temp_esc = nil
    return
  end

  if lastAlertAt.temp_esc and (now - lastAlertAt.temp_esc) < 10 then return end
  lastAlertAt.temp_esc = now
  playAlert("esctemp.wav")
  haptic()
end

local function announceBecRxVoltage(now)
  if not (events.bec_voltage or events.rx_voltage) then return end
  if session.connected ~= true then return end

  local voltage = tonumber(session.becVoltage)
  if voltage == nil then return end
  local avgVoltage = updateRollingAverage("bec_voltage", voltage, 5)

  if events.bec_voltage then
    local threshold = tonumber(events.becalertvalue) or 6.5
    if avgVoltage < threshold then
      if not lastAlertAt.bec_voltage or (now - lastAlertAt.bec_voltage) >= 10 then
        lastAlertAt.bec_voltage = now
        playAlert("becvolt.wav")
        haptic()
      end
    else
      lastAlertAt.bec_voltage = nil
    end
  else
    lastAlertAt.bec_voltage = nil
  end

  if events.rx_voltage then
    local threshold = tonumber(events.rxalertvalue) or 7.4
    if avgVoltage < threshold then
      if not lastAlertAt.rx_voltage or (now - lastAlertAt.rx_voltage) >= 10 then
        lastAlertAt.rx_voltage = now
        playAlert("rxvolt.wav")
        haptic()
      end
    else
      lastAlertAt.rx_voltage = nil
    end
  else
    lastAlertAt.rx_voltage = nil
  end
end

local function smartfuelThresholds()
  local step = tonumber(events.smartfuelcallout) or 10
  return SMARTFUEL_THRESHOLDS[step] or SMARTFUEL_THRESHOLDS[10]
end

local function resetLowFuel()
  lastLowFuelAnnounced = false
  lastLowFuelRepeatAt = 0
  lastLowFuelRepeatCount = 0
end

local function resetFuelAnnouncements()
  lastSmartfuelAnnounced = nil
  fuelEvaluated = false
  resetLowFuel()
end

-- Seed on the first reading, whatever it says.
--
-- The threshold loop below already did this for every value above zero: it took
-- `lastSmartfuelAnnounced == nil` as "nothing to compare against yet", recorded
-- the value and returned without a sound. The zero branch had no such gate, so
-- a fuel reading of 0 on the first evaluation after connecting went straight
-- into lowfuel.wav and latched lastLowFuelAnnounced -- and 0 is exactly what a
-- sensor that has not received a frame yet can report, so powering the radio
-- with a freshly charged pack announced "low fuel".
--
-- A 0 is not distinguishable from a real reading by value alone: an empty pack
-- reads 0 too. So this seeds the first 0 instead of announcing it, and lets
-- every later one through -- an empty pack is then announced from the second
-- evaluation on, one wakeup later. The alternative of requiring a value above
-- 0 before trusting any reading at all (which is what #2313 suggested) would
-- silence the low-fuel warning for a genuinely empty pack forever, since such a
-- pack never reads above 0.
--
-- resetFuelAnnouncements() clears this alongside lastSmartfuelAnnounced, so a
-- reconnect or a pack change starts the seeding over.
local function announceSmartfuel(now)
  if not events.smartfuel then return end
  if session.connected ~= true then return end

  local value = tonumber(session.fuelPercent)
  if value == nil then return end
  value = math.floor(value + 0.5)

  if not fuelEvaluated then
    fuelEvaluated = true
    lastSmartfuelAnnounced = value
    resetLowFuel()
    return
  end

  if value <= 0 then
    local repeats = tonumber(events.smartfuelrepeats) or 1
    local lowAlert = lowCalloutAlert()
    if not lastLowFuelAnnounced then
      playCalloutAlert(lowAlert)
      if events.smartfuelhaptic then haptic() end
      lastLowFuelAnnounced = true
      lastLowFuelRepeatAt = now
      lastLowFuelRepeatCount = 1
    elseif lastLowFuelRepeatCount < repeats and (now - lastLowFuelRepeatAt) >= 10 then
      playCalloutAlert(lowAlert)
      if events.smartfuelhaptic then haptic() end
      lastLowFuelRepeatAt = now
      lastLowFuelRepeatCount = lastLowFuelRepeatCount + 1
    end
    return
  end
  resetLowFuel()

  local thresholds = smartfuelThresholds()
  if not thresholds then
    lastSmartfuelAnnounced = value
    return
  end

  for i = 1, #thresholds do
    local threshold = thresholds[i]
    if value <= threshold and lastSmartfuelAnnounced > threshold then
      local percentAlert, fromEvents = percentCalloutAlert()
      playCalloutAlert(percentAlert, fromEvents)
      playNumber(threshold, UNIT_PERCENT)
      lastSmartfuelAnnounced = threshold
      return
    end
  end
  lastSmartfuelAnnounced = value
end

-- An in-flight adjustment: the function's name when it changes, and the value.
--
-- Nothing is spoken on the step itself. Every step restarts a settle window,
-- and the announcement goes out once the value has stood still for
-- ADJ_SETTLE_SECONDS -- so a burst of clicks on a trim switch says one number,
-- and it is the one the model ended up with (issue #2315). Speaking each step
-- as it arrived did the opposite of what the pilot needs: the first step was
-- spoken, the ones that landed while that number was still playing were
-- dropped by canSpeak(), and the last of them was the value in the model.
--
-- A change that has settled while an earlier announcement is still playing
-- stays pending rather than being dropped, for the same reason.
local function announceAdjustment(now)
  if not (events.adj_f or events.adj_v) then
    pendingAdjFunction = false
    adjChangedAt = nil
    return
  end
  if session.connected ~= true then return end

  local adjFunction = tonumber(session.adjFunction)
  local adjValue = tonumber(session.adjValue)
  local previousFunction = tonumber(previous.adjFunction)
  local previousValue = tonumber(previous.adjValue)
  if adjFunction == nil or adjValue == nil then return end
  adjFunction = math.floor(adjFunction)
  adjValue = math.floor(adjValue)

  local functionChanged = previousFunction ~= nil and adjFunction ~= previousFunction
  local valueChanged = previousValue ~= nil and adjValue ~= previousValue
  if functionChanged then pendingAdjFunction = true end
  if pendingAdjFunction and (adjFunction == 0 or not events.adj_f) then pendingAdjFunction = false end

  if (events.adj_f and functionChanged) or ((events.adj_v or pendingAdjFunction) and valueChanged) then adjChangedAt = now end
  -- The flight controller reports function 0 while nothing is being adjusted.
  if adjFunction == 0 then adjChangedAt = nil end

  if not adjChangedAt then return end
  if (now - adjChangedAt) < ADJ_SETTLE_SECONDS then return end
  if not canSpeak(now) then return end
  adjChangedAt = nil

  if pendingAdjFunction then
    pendingAdjFunction = false
    if speakAdjFunction(adjFunction, now) then
      speakAdjValue(adjValue, speakingUntil)
    end
    return
  end

  if events.adj_v then speakAdjValue(adjValue, now) end
end

local function resetTimerAudio()
  timerTriggered = false
  timerLastBeep = nil
  timerPreLastBeep = nil
end

local function announceTimer()
  if not timer then
    resetTimerAudio()
    return
  end
  if not timer.timeraudioenable then
    resetTimerAudio()
    return
  end
  if session.connected ~= true then
    resetTimerAudio()
    return
  end
  if session.isArmed ~= true then
    resetTimerAudio()
    return
  end

  local targetSeconds = tonumber(session.timerTarget) or 0
  if targetSeconds <= 0 then
    resetTimerAudio()
    return
  end

  local elapsed = tonumber(session.timerLive) or 0
  local elapsedMode = tonumber(timer.elapsedalertmode) or 0

  if timer.prealerton then
    local prePeriod = tonumber(timer.prealertperiod) or 30
    local preAlertStart = targetSeconds - prePeriod
    if elapsed >= preAlertStart and elapsed < targetSeconds then
      local preInterval = tonumber(timer.prealertinterval) or 10
      if not timerPreLastBeep or (elapsed - timerPreLastBeep) >= preInterval then
        playCommon("beep.wav")
        timerPreLastBeep = elapsed
      end
      timerTriggered = false
      timerLastBeep = nil
      return
    end
  else
    timerPreLastBeep = nil
  end

  if elapsed >= targetSeconds then
    if not timerTriggered then
      if elapsedMode == 0 then
        playCommon("beep.wav")
      elseif elapsedMode == 1 then
        playCommon("multibeep.wav")
      elseif elapsedMode == 2 then
        playAlert("elapsed.wav")
      elseif elapsedMode == 3 then
        playStatus("timer.wav")
        playNumber(targetSeconds, UNIT_SECOND)
      end
      timerTriggered = true
      timerLastBeep = elapsed
    end

    if timer.postalerton then
      local postPeriod = tonumber(timer.postalertperiod) or 60
      if elapsed < (targetSeconds + postPeriod) then
        local postInterval = tonumber(timer.postalertinterval) or 10
        if not timerLastBeep or (elapsed - timerLastBeep) >= postInterval then
          playCommon("beep.wav")
          timerLastBeep = elapsed
        end
      end
    end
  else
    timerTriggered = false
    timerLastBeep = nil
  end
end

-- FC status callouts from lib/system_alerts.lua's rules. A condition already
-- present when the word its rule reads first arrives becomes the baseline
-- silently (the dashboard banner shows it), and a rule is left alone until
-- that word arrives; after that each change is announced once it has held for
-- the rule's debounce. Not armed-gated: a full Blackbox or a silent
-- GPS matters on the bench too.
local function announceSystemAlerts(now)
  local status = session.systemStatus
  local config = session.systemConfig
  if status == nil and config == nil then return end
  if not systemAlerts then systemAlerts = requireModule("lib/system_alerts.lua") end
  local rules = systemAlerts.RULES

  for i = 1, #rules do
    local rule = rules[i]
    if rule.enterSound and systemAlerts.hasWords(rule, status, config) then
      local active = systemAlerts.isActive(rule, status, config)
      local state = alertState[rule.id]
      if state == nil then
        alertState[rule.id] = {reported = active, pending = nil, since = now}
      elseif active == state.reported then
        state.pending = nil
      else
        if state.pending ~= active then
          state.pending = active
          state.since = now
        end
        if now - state.since >= (rule.debounce or 0) then
          state.reported = active
          state.pending = nil
          if active and events[rule.setting] then playAlert(rule.enterSound) end
        end
      end
    end
  end
end

-- Stabilized cyclic, yaw or collective hit its mixer limit (the FC holds the
-- flag for 500 ms). Rate-limited, and off by default: it can be chatty in 3D
-- flight.
local function announceControlLimit(now)
  if not events.status_saturation then return end
  local status = session.systemStatus
  if not (status and status.controlSaturated) then return end
  if lastAlertAt.control_limit and (now - lastAlertAt.control_limit) < CONTROL_LIMIT_REPEAT_SECONDS then return end
  lastAlertAt.control_limit = now
  playAlert("controllimit.wav")
end

local function clearAlertState()
  for key in pairs(alertState) do alertState[key] = nil end
end

local function rememberCurrent()
  previous.connected = session.connected
  previous.isArmed = session.isArmed
  previous.pidProfile = session.pidProfile
  previous.rateProfile = session.rateProfile
  previous.batteryProfile = session.batteryProfile
  previous.governorState = session.governorState
  previous.adjFunction = session.adjFunction
  previous.adjValue = session.adjValue
end

function audio_events.wakeup()
  ensureSettings()
  local now = os.clock()
  if session.connected ~= true then
    -- Whether this tick is the loss itself, read before rememberCurrent()
    -- below overwrites `previous` with the values of the down session. Both
    -- edges the link announcement needs -- that the link went, and that the
    -- model was armed when it did -- are only in `previous` on this one tick.
    local linkLost = previous.connected == true
    initialized = false
    craftNameAnnounced = false
    resetFuelAnnouncements()
    adjWavs = nil
    pendingAdjFunction = false
    adjChangedAt = nil
    resetTimerAudio()
    speakingUntil = 0
    packVoltageSeen = false
    mainPowerLostActive = false
    lowVoltageHoldStart = nil
    -- connectionLostAt is deliberately NOT cleared here: it has to outlive the
    -- very disconnect that set it, or the recovery has nothing left to be
    -- gated on. announceTelemetryRecovered() drops it, by window or by the
    -- model answering.
    for key in pairs(rollingSamples) do rollingSamples[key] = nil end
    for key in pairs(lastAlertAt) do lastAlertAt[key] = nil end
    clearAlertState()
    -- Before rememberCurrent(): the announcement reads `previous`, and that
    -- call is what overwrites it with the values of the down session.
    if linkLost then announceTelemetryLost(now) end
    rememberCurrent()
    return
  end

  if not initialized then
    initialized = true
    rememberCurrent()
    -- The first connected tick after a link loss. Nothing else runs on it --
    -- this is the branch that keeps the first evaluation after a connect from
    -- carrying a sound -- so the recovery is announced from here.
    announceTelemetryRecovered(now)
    -- No fuel seed here: announceSmartfuel() seeds the first reading it
    -- evaluates, whatever that reading is, and gating it in two places is how
    -- the zero case came to be announced at all. Skipping this branch is what
    -- keeps the first evaluation after a connect from carrying a sound.
    return
  end

  announceCraftName()
  announceArmed()
  announceProfile("pidProfile", events.pid_profile, "profile.wav")
  announceProfile("rateProfile", events.rate_profile, "rates.wav")
  announceBatteryProfile()
  announceGovernor()
  announceSystemAlerts(now)
  announceControlLimit(now)
  announceVoltage(now)
  announceEscTemp(now)
  announceBecRxVoltage(now)
  announceMainPowerLost(now)
  announceSmartfuel(now)
  announceTimer()
  announceAdjustment(now)
  rememberCurrent()
end

function audio_events.reset()
  initialized = false
  craftNameAnnounced = false
  adjWavs = nil
  for key in pairs(previous) do previous[key] = nil end
  for key in pairs(lastAlertAt) do lastAlertAt[key] = nil end
  clearAlertState()
  resetFuelAnnouncements()
  pendingAdjFunction = false
  adjChangedAt = nil
  resetTimerAudio()
  speakingUntil = 0
  packVoltageSeen = false
  mainPowerLostActive = false
  connectionLostAt = nil
  lowVoltageHoldStart = nil
  for key in pairs(rollingSamples) do rollingSamples[key] = nil end
end

function audio_events.setSettings(snapshot)
  onSettingsUpdate(snapshot)
end

return audio_events
