-- Lightweight session-driven audio events.

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local bus = requireModule("lib/bus.lua")
local batteryProfileIndex = requireModule("lib/battery_profile_index.lua")
local engineType = requireModule("lib/engine_type.lua")
local modelPreferences = requireModule("lib/model_preferences.lua")
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
local craftNameAnnounced = false
local lastSmartfuelAnnounced = nil
local lastLowFuelAnnounced = false
local lastLowFuelRepeatAt = 0
local lastLowFuelRepeatCount = 0
local pendingAdjFunction = false
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
  "mcuId",
  "craftName",
  "isArmed",
  "pidProfile",
  "rateProfile",
  "batteryProfile",
  "governorMode",
  "governorState",
  "voltage",
  "batteryConfig",
  "tempEsc",
  "becVoltage",
  "fuelPercent",
  "adjFunction",
  "adjValue",
  "timerLive",
  "timerTarget",
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
-- MODEL_TYPE_CHOICES) and the configured battery config. Auto is *resolved*
-- from the config, not guessed: a cell count or a configured pack capacity
-- means a battery. Same rule as widgets/dashboard/context.lua's
-- isElectricEngine(), both now reading lib/engine_type.lua.
local modelTypeCacheMcuId = nil
local modelTypeCacheValue = 0

local function clearModelTypeCache()
  modelTypeCacheMcuId = nil
  modelTypeCacheValue = 0
end

local function currentModelType()
  local mcuId = session.mcuId
  if type(mcuId) ~= "string" or mcuId == "" then
    if modelTypeCacheMcuId ~= nil then clearModelTypeCache() end
    return 0
  end
  if mcuId ~= modelTypeCacheMcuId then
    local prefs = modelPreferences.load(mcuId)
    modelTypeCacheMcuId = mcuId
    modelTypeCacheValue = tonumber(prefs and prefs.battery and prefs.battery.smartfuel_model_type) or 0
  end
  return modelTypeCacheValue
end

local function isElectricModel()
  return engineType.isElectric(session.batteryConfig, currentModelType())
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
-- The SmartFuel page publishes this after it changes the model type, so the
-- cache has to be updated or the new word only appears after a reconnect.
-- See app/pages/power_smartfuel.lua's own publish and tasks/session.lua's
-- handler for the same payload shape. The payload carries the new value, so
-- there is no need to re-read the file here.
bus.subscribe("model.smartfuel_type.update", function(payload)
  if type(payload) ~= "table" then return end
  if type(payload.mcuId) ~= "string" or payload.mcuId == "" then return end
  if payload.mcuId ~= session.mcuId then return end
  modelTypeCacheMcuId = payload.mcuId
  modelTypeCacheValue = tonumber(payload.smartfuelModelType) or engineType.AUTO
end)

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

  playAlert("battery.wav")
  playNumber(math.floor(capacity + 0.5), UNIT_MILLIAMPERE_HOUR)
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
  if not events.voltage then return end
  if session.connected ~= true then return end

  local voltage = tonumber(session.voltage)
  local config = session.batteryConfig
  local cellCount = tonumber(config and config.cellCount)
  local warnCell = tonumber(config and config.vbatWarningCell)
  if voltage == nil or cellCount == nil or cellCount <= 0 or warnCell == nil or warnCell <= 0 then return end

  -- Below 1V total is implausible for a connected battery (e.g. running on
  -- USB power alone with no pack attached) -- don't let a near-zero noise
  -- reading trigger the low-voltage alarm.
  if voltage < 1 then
    lastAlertAt.voltage = nil
    return
  end

  local cellVoltage = voltage / cellCount
  if cellVoltage >= warnCell then
    lastAlertAt.voltage = nil
    return
  end

  local repeatInterval = tonumber(events.voltage_repeat_interval) or 10
  if lastAlertAt.voltage and (now - lastAlertAt.voltage) < repeatInterval then return end
  lastAlertAt.voltage = now
  playAlert("lowvoltage.wav")
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

local function announceSmartfuel(now)
  if not events.smartfuel then return end
  if session.connected ~= true then return end

  local value = tonumber(session.fuelPercent)
  if value == nil then return end
  value = math.floor(value + 0.5)

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

  if lastSmartfuelAnnounced == nil then
    lastSmartfuelAnnounced = value
    return
  end

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

local function announceAdjustment(now)
  if not (events.adj_f or events.adj_v) then return end
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

  if pendingAdjFunction and adjFunction ~= 0 and events.adj_f then
    if canSpeak(now) then
      if speakAdjFunction(adjFunction, now) then
        speakAdjValue(adjValue, speakingUntil)
      end
      pendingAdjFunction = false
    end
    return
  end

  if valueChanged and adjFunction ~= 0 and events.adj_v and canSpeak(now) then
    speakAdjValue(adjValue, now)
  end
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
    initialized = false
    craftNameAnnounced = false
    lastSmartfuelAnnounced = nil
    adjWavs = nil
    resetLowFuel()
    pendingAdjFunction = false
    resetTimerAudio()
    speakingUntil = 0
    for key in pairs(rollingSamples) do rollingSamples[key] = nil end
    for key in pairs(lastAlertAt) do lastAlertAt[key] = nil end
    rememberCurrent()
    return
  end

  if not initialized then
    initialized = true
    rememberCurrent()
    lastSmartfuelAnnounced = tonumber(session.fuelPercent)
    return
  end

  announceCraftName()
  announceArmed()
  announceProfile("pidProfile", events.pid_profile, "profile.wav")
  announceProfile("rateProfile", events.rate_profile, "rates.wav")
  announceBatteryProfile()
  announceGovernor()
  announceVoltage(now)
  announceEscTemp(now)
  announceBecRxVoltage(now)
  announceSmartfuel(now)
  announceTimer()
  announceAdjustment(now)
  rememberCurrent()
end

function audio_events.reset()
  initialized = false
  craftNameAnnounced = false
  adjWavs = nil
  clearModelTypeCache()
  for key in pairs(previous) do previous[key] = nil end
  for key in pairs(lastAlertAt) do lastAlertAt[key] = nil end
  lastSmartfuelAnnounced = nil
  pendingAdjFunction = false
  resetTimerAudio()
  speakingUntil = 0
  for key in pairs(rollingSamples) do rollingSamples[key] = nil end
  resetLowFuel()
end

function audio_events.setSettings(snapshot)
  onSettingsUpdate(snapshot)
end

return audio_events
