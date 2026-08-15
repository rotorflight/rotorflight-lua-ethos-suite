-- Switch-driven telemetry value callouts.

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local bus = requireModule("lib/bus.lua")
local settingsStore = requireModule("lib/settings_store.lua")

local audio_switches = {}

local settings = nil
local switches = nil
local telemetrySensors = nil
local switchSources = {}
local lastPlayAt = {}
local lastSwitchState = {}
local startAt = nil
local initialized = false

local STARTUP_GRACE_SECONDS = 5
local REPEAT_SECONDS = 10

local SWITCH_UNITS = {
  altitude = UNIT_METER,
  voltage = UNIT_VOLT,
  current = UNIT_AMPERE,
  consumption = UNIT_MILLIAMPERE_HOUR,
  rpm = UNIT_RPM,
  temp_esc = UNIT_DEGREE,
  bec_voltage = UNIT_VOLT,
  throttle_percent = UNIT_PERCENT,
  smartfuel = UNIT_PERCENT,
}

local function parseSwitch(value)
  if type(value) ~= "string" then return nil end
  local category, member = value:match("([^,]+),([^,]+)")
  category = tonumber(category)
  member = tonumber(member)
  if not category or not member then return nil end
  return {category = category, member = member}
end

local function clearRuntime()
  for key in pairs(switchSources) do switchSources[key] = nil end
  for key in pairs(lastPlayAt) do lastPlayAt[key] = nil end
  for key in pairs(lastSwitchState) do lastSwitchState[key] = nil end
  startAt = nil
  initialized = false
end

local function onSettingsUpdate(snapshot)
  settings = snapshot or {}
  switches = settingsStore.audioSwitches(settings)
  clearRuntime()
end

bus.subscribe("settings.update", onSettingsUpdate)

local function ensureSettings()
  if settings then return end
  settings = settingsStore.load()
  switches = settingsStore.audioSwitches(settings)
end

local function initializeSwitches()
  ensureSettings()
  clearRuntime()
  for key, value in pairs(switches or {}) do
    local query = parseSwitch(value)
    if query then
      switchSources[key] = system.getSource(query)
    end
  end
  initialized = true
end

local function hasSwitches()
  for _ in pairs(switchSources) do return true end
  return false
end

local function playTelemetryValue(protocol, key)
  if not telemetrySensors then return false end
  local source = telemetrySensors.getSource(protocol, key)
  if not source then return false end
  local value = source:value()
  if type(value) ~= "number" then return false end
  local unit = SWITCH_UNITS[key]
  local decimals = nil
  if source.decimals then decimals = tonumber(source:decimals()) end
  if system.playNumber then system.playNumber(value, unit, decimals) end
  return true
end

function audio_switches.wakeup(protocol)
  ensureSettings()
  local now = os.clock()
  if not initialized then initializeSwitches() end
  if not hasSwitches() then return end
  if not startAt then startAt = now end
  if (now - startAt) <= STARTUP_GRACE_SECONDS then return end

  for key, switchSource in pairs(switchSources) do
    local currentState = switchSource and switchSource.state and switchSource:state() == true
    if not currentState then
      lastSwitchState[key] = false
    else
      local previousState = lastSwitchState[key] or false
      local lastTime = lastPlayAt[key] or 0
      if (not previousState) or (now - lastTime) >= REPEAT_SECONDS then
        if playTelemetryValue(protocol, key) then
          lastPlayAt[key] = now
        end
      end
      lastSwitchState[key] = true
    end
  end
end

function audio_switches.reset()
  clearRuntime()
end

function audio_switches.setSettings(snapshot)
  onSettingsUpdate(snapshot)
end

function audio_switches.setTelemetrySensors(instance)
  telemetrySensors = instance
end

return audio_switches
