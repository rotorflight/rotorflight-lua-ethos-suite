-- Whether a model is powered by a battery, which decides the wording the
-- suite uses in front of its fuel/smartfuel announcements.
--
-- The flight controller has no powerplant concept at all: no tank, no fuel,
-- no nitro or gas anywhere under its src/main (a search for fuelTank /
-- fuel_tank / tankSize / fuelCapacity / nitro returns nothing), and no battery
-- chemistry either. batteryCellCount is not a signal for "no battery" -- its
-- own comment in src/main/pg/battery.h says "zero for autodetection", and
-- src/main/sensors/battery.c counts the cells off the measured voltage, which
-- always yields at least one.
--
-- What the flight controller does have is the configured battery config: the
-- cell count and the six pack capacities. A model that has a cell count or a
-- configured pack capacity has a battery. widgets/dashboard/context.lua's
-- isElectricEngine() has used exactly that proxy since before this module
-- existed; the criteria now live here so the dashboard and the audio callouts
-- read the same rule instead of two copies of it drifting apart.

if package.loaded["rfsuite.lib.engine_type"] then
  return package.loaded["rfsuite.lib.engine_type"]
end

local engine_type = {}

-- The values of app/pages/power_smartfuel.lua's MODEL_TYPE_CHOICES. Auto is
-- the transmitter-side default, and it is resolved by the config below rather
-- than guessed at from a second, contradictory default.
engine_type.AUTO = 0
engine_type.ELECTRIC = 1
engine_type.NITRO = 2

-- A pack capacity entry is a plain number with the decoder in lib/msp_battery.lua,
-- but the dashboard also tolerates a string and a {capacity=} / {name=} table,
-- so all three shapes are read. Ported from context.lua's own helper, which
-- existed for that reason.
local function configuredCapacity(value)
  if type(value) == "number" then return value end
  if type(value) == "string" then return tonumber(value:match("(%d+)")) end
  if type(value) == "table" then
    if type(value.capacity) == "number" then return value.capacity end
    if type(value.capacity) == "string" then return tonumber(value.capacity:match("(%d+)")) end
    if type(value.name) == "string" then return tonumber(value.name:match("(%d+)")) end
  end
  return nil
end

-- Both index ranges are checked, because which one holds the profiles depends
-- on the decoder: lib/msp_battery.lua fills profiles[0]..[5], while a
-- list-shaped table would be 1..6.
function engine_type.hasConfiguredBatteryCapacity(config)
  if not config then return false end
  local capacity = tonumber(config.batteryCapacity) or 0
  if capacity > 0 then return true end

  local profiles = config.profiles
  if type(profiles) ~= "table" then return false end
  for i = 0, 5 do
    capacity = configuredCapacity(profiles[i])
    if capacity and capacity > 0 then return true end
  end
  for i = 1, 6 do
    capacity = configuredCapacity(profiles[i])
    if capacity and capacity > 0 then return true end
  end
  return false
end

-- config is the battery config table (session.batteryConfig /
-- widget.batteryConfig), or nil when none has been read yet -- which is the
-- same "no config, therefore no battery" answer the dashboard already gave.
function engine_type.isElectric(config, modelType)
  modelType = tonumber(modelType) or engine_type.AUTO
  if modelType == engine_type.AUTO then
    if not config then return false end
    local cellCount = tonumber(config.cellCount or config.batteryCellCount) or 0
    return cellCount ~= 0 or engine_type.hasConfiguredBatteryCapacity(config)
  end
  return modelType == engine_type.ELECTRIC
end

package.loaded["rfsuite.lib.engine_type"] = engine_type
return engine_type
