-- Auto-creation/rename of Rotorflight's custom S.Port telemetry sensors,
-- driven by the FC's own TELEMETRY_CONFIG (lib/msp_telemetry_config.lua)
-- rather than reactively watching every incoming frame. Mirrors
-- rotorflight-lua-ethos-suite's tasks/scheduler/sensors/frsky.lua -- the
-- modern, config-driven variant that suite uses for API >= 12.0.8. This
-- rebuild's floor is >= 12.09 (see AGENTS.md), so that's always the
-- applicable variant; the older frsky_legacy.lua's per-frame reactive tap
-- (its fallback for API < 12.0.8) is dead code for this rebuild's target
-- and was deliberately not ported.
--
-- Why config-driven beats reactive: tasks/session.lua already reads
-- TELEMETRY_CONFIG once per connection (same one-shot-read pattern as
-- BATTERY_CONFIG/FC_VERSION/etc. in that file's runHandshake()). That
-- single read's 40 sensor-ID slots (translated to appIds via
-- lib/frsky_sid_lookup.lua) say in one shot exactly which appIds will
-- ever appear on the wire -- so sensors get created once, right after
-- connect, with zero ongoing per-frame cost, instead of checking every
-- single S.Port frame the transport pops for the rest of the connection.
--
-- No drop-sensor step: the original's dropSensorList only ever fires for
-- API version < 12.0.8 (dead code given this rebuild's floor).
--
-- One instance per connection's lifetime, created once by
-- tasks/session.lua -- same per-instance-state convention as
-- lib/smartfuel_calc.lua's SmartFuel.new().

local system_getSource = system.getSource
local model_createSensor = model.createSensor
local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local sidLookup = requireModule("lib/frsky_sid_lookup.lua")
local debugLog = requireModule("lib/debug_log.lua")

-- Fixed physId/module every created sensor uses. 27 (0x1B) is
-- SPORT_REMOTE_SENSOR_ID (see tasks/msp/transport_sport.lua) -- there's no
-- specific incoming frame to read a physId off at provisioning time (this
-- runs from an MSP reply, not a popped telemetry frame), so a fixed
-- constant matching the FC's own S.Port sensor ID is what the original
-- itself hardcodes here too. Module 0 matches the same "always module 0"
-- simplification already accepted in tasks/msp/transport_sport.lua.
local FIXED_PHYS_ID = 0x1B
local MODULE_INDEX = 0

-- appId -> {name, unit, decimals?}. Transcribed from the original's
-- frsky.lua createSensorList, not independently verified against real
-- hardware by this rebuild.
local CREATE_LIST = {
  [0x5100] = {name = "Heartbeat", unit = UNIT_RAW},
  [0x5250] = {name = "Consumption", unit = UNIT_MILLIAMPERE_HOUR},
  [0x5260] = {name = "Cell Count", unit = UNIT_RAW},
  [0x51A0] = {name = "Pitch Control", unit = UNIT_DEGREE, decimals = 2},
  [0x51A1] = {name = "Roll Control", unit = UNIT_DEGREE, decimals = 2},
  [0x51A2] = {name = "Yaw Control", unit = UNIT_DEGREE, decimals = 2},
  [0x51A3] = {name = "Collective Ctrl", unit = UNIT_DEGREE, decimals = 2},
  [0x51A4] = {name = "Throttle %", unit = UNIT_PERCENT, decimals = 1},
  [0x5258] = {name = "ESC1 Capacity", unit = UNIT_MILLIAMPERE_HOUR},
  [0x5268] = {name = "ESC1 Power", unit = UNIT_PERCENT},
  [0x5269] = {name = "ESC1 Throttle", unit = UNIT_PERCENT, decimals = 1},
  [0x5128] = {name = "ESC1 Status", unit = UNIT_RAW},
  [0x5129] = {name = "ESC1 Model ID", unit = UNIT_RAW},
  [0x525A] = {name = "ESC2 Capacity", unit = UNIT_MILLIAMPERE_HOUR},
  [0x512B] = {name = "ESC2 Model ID", unit = UNIT_RAW},
  [0x51D0] = {name = "CPU Load", unit = UNIT_PERCENT},
  [0x51D1] = {name = "System Load", unit = UNIT_PERCENT},
  [0x51D2] = {name = "RT Load", unit = UNIT_PERCENT},
  [0x5120] = {name = "Model ID", unit = UNIT_RAW},
  [0x5121] = {name = "Flight Mode", unit = UNIT_RAW},
  [0x5122] = {name = "Arm Flags", unit = UNIT_RAW},
  [0x5123] = {name = "Arm Dis Flags", unit = UNIT_RAW},
  [0x5124] = {name = "Rescue State", unit = UNIT_RAW},
  [0x5125] = {name = "Gov State", unit = UNIT_RAW},
  [0x5130] = {name = "PID Profile", unit = UNIT_RAW},
  [0x5131] = {name = "Rates Profile", unit = UNIT_RAW},
  [0x5132] = {name = "LED Profile", unit = UNIT_RAW},
  [0x5133] = {name = "Battery Profile", unit = UNIT_RAW},
  [0x5110] = {name = "Adj Function", unit = UNIT_RAW},
  [0x5111] = {name = "Adj Value", unit = UNIT_RAW},
  [0x5210] = {name = "Heading", unit = UNIT_DEGREE, decimals = 1},
}

-- appId -> {name, onlyIfName}: renamed only if Ethos's own discovery
-- already created it under the generic FrSky name (never clobbers a
-- sensor a pilot renamed themselves). The original's own 0x5210 rename
-- rule ("Y.angle", onlyifname="Heading") is not ported -- it would rename
-- the "Heading" sensor CREATE_LIST above just created back out from under
-- itself; that looks like leftover/dead logic in the original rather than
-- something intentional.
local RENAME_LIST = {
  [0x0500] = {name = "Headspeed", onlyIfName = "RPM"},
  [0x0501] = {name = "Tailspeed", onlyIfName = "RPM"},
  [0x0210] = {name = "Voltage", onlyIfName = "VFAS"},
  [0x0600] = {name = "Charge Level", onlyIfName = "Fuel"},
  [0x0910] = {name = "Cell Voltage", onlyIfName = "ADC4"},
  [0x0211] = {name = "ESC Voltage", onlyIfName = "VFAS"},
  [0x0B70] = {name = "ESC Temp", onlyIfName = "ESC temp"},
  [0x0218] = {name = "ESC1 Voltage", onlyIfName = "VFAS"},
  [0x0208] = {name = "ESC1 Current", onlyIfName = "Current"},
  [0x0508] = {name = "ESC1 RPM", onlyIfName = "RPM"},
  [0x0418] = {name = "ESC1 Temp", onlyIfName = "Temp2"},
  [0x0219] = {name = "BEC1 Voltage", onlyIfName = "VFAS"},
  [0x0229] = {name = "BEC1 Current", onlyIfName = "Current"},
  [0x0419] = {name = "BEC1 Temp", onlyIfName = "Temp2"},
  [0x021A] = {name = "ESC2 Voltage", onlyIfName = "VFAS"},
  [0x020A] = {name = "ESC2 Current", onlyIfName = "Current"},
  [0x050A] = {name = "ESC2 RPM", onlyIfName = "RPM"},
  [0x041A] = {name = "ESC2 Temp", onlyIfName = "Temp2"},
  [0x0840] = {name = "GPS Heading", onlyIfName = "GPS course"},
  [0x0900] = {name = "MCU Voltage", onlyIfName = "ADC3"},
  [0x0901] = {name = "BEC Voltage", onlyIfName = "ADC3"},
  [0x0902] = {name = "BUS Voltage", onlyIfName = "ADC3"},
  [0x0201] = {name = "ESC Current", onlyIfName = "Current"},
  [0x0222] = {name = "BEC Current", onlyIfName = "Current"},
  [0x0400] = {name = "MCU Temp", onlyIfName = "Temp1"},
  [0x0401] = {name = "ESC Temp", onlyIfName = "Temp1"},
  [0x0402] = {name = "BEC Temp", onlyIfName = "Temp1"},
}

-- Returns true if a sensor was newly created, false if one already existed.
local function resolveOrCreate(appId, meta)
  local existing = system_getSource({category = CATEGORY_TELEMETRY_SENSOR, appId = appId})
  if existing then return false end

  local sensor = model_createSensor()
  sensor:name(meta.name)
  sensor:appId(appId)
  sensor:physId(FIXED_PHYS_ID)
  sensor:module(MODULE_INDEX)
  if meta.unit then
    sensor:unit(meta.unit)
    sensor:protocolUnit(meta.unit)
  end
  if meta.decimals then
    sensor:decimals(meta.decimals)
    sensor:protocolDecimals(meta.decimals)
  end
  sensor:minimum(meta.minimum or -1000000000)
  sensor:maximum(meta.maximum or 2147483647)
  return true
end

-- Returns true if a rename actually happened.
local function maybeRename(appId, meta)
  local source = system_getSource({category = CATEGORY_TELEMETRY_SENSOR, appId = appId})
  if source and source:name() == meta.onlyIfName then
    source:name(meta.name)
    return true
  end
  return false
end

local FrskySensors = {}
FrskySensors.__index = FrskySensors

function FrskySensors.new()
  return setmetatable({provisioned = false}, FrskySensors)
end

-- `slots`: the 40-entry array lib/msp_telemetry_config.lua decodes (each
-- entry an FC-internal sensor-ID slot value, 0 = slot unused). Runs at
-- most once per connection -- see tasks/session.lua.
function FrskySensors:provision(slots)
  if self.provisioned then return true end
  if system.isSensorDiscoverActive and system.isSensorDiscoverActive() then
    if not self.discoveryDeferLogged then
      self.discoveryDeferLogged = true
      debugLog.print("[frsky] sensor discovery active; deferring provisioning")
    end
    return false
  end

  self.provisioned = true
  self.discoveryDeferLogged = false

  local created, existing, renamed = 0, 0, 0

  for i = 1, #slots do
    local sid = slots[i]
    if sid and sid ~= 0 then
      local appIds = sidLookup[sid]
      if appIds then
        for j = 1, #appIds do
          local appId = appIds[j]
          local createMeta = CREATE_LIST[appId]
          if createMeta then
            if resolveOrCreate(appId, createMeta) then
              created = created + 1
            else
              existing = existing + 1
            end
          end
          local renameMeta = RENAME_LIST[appId]
          if renameMeta and maybeRename(appId, renameMeta) then
            renamed = renamed + 1
          end
        end
      end
    end
  end

  debugLog.format("[frsky] provisioned: %d created, %d already present, %d renamed", created, existing, renamed)
  return true
end

-- Called on disconnect so the next connection re-provisions from scratch
-- -- the pilot may have changed which sensors are assigned to which slot
-- (or reconnected to a different aircraft) since the last read.
function FrskySensors:reset()
  self.provisioned = false
  self.discoveryDeferLogged = false
end

return FrskySensors
