-- Flight phase and flight extremes, owned by the session (#2344).
--
-- The session calls update(session) every tick, so the phase and the extremes are
-- kept whether a dashboard is open or not. The dashboard and the ActiveLook widget
-- only read the result from the session snapshot (`flightState`, `flight`).
--
-- Phases: preflight, armed, inflight, postflight, offline. The rules are the ones the
-- dashboard used to apply itself (its tracker plus the reconnect and craft-change
-- resets around it).

local flight_stats = {}

-- Session field, min key, max key, average key. One row per recorded value.
local FIELDS = {
  "voltage", "minVoltage", "maxVoltage", "voltage",
  "consumption", "minConsumption", "maxConsumption", "consumption",
  "current", "minCurrent", "maxCurrent", "current",
  "throttlePercent", "minThrottlePercent", "maxThrottlePercent", "throttle_percent",
  "rpm", "minRpm", "maxRpm", "rpm",
  "linkQuality", "minLink", "maxLink", "link",
  "tempEsc", "minTempEsc", "maxTempEsc", "temp_esc",
  "tempMcu", "minTempMcu", "maxTempMcu", "temp_mcu",
  "becVoltage", "minBecVoltage", "maxBecVoltage", "bec_voltage",
  "fuelPercent", "minFuelPercent", "maxFuelPercent", "smartfuel",
}

-- One value into the extremes: flat min/max keys (when given) and the
-- {min, max, sum, count, avg} entry under `key`. Shared with the dashboard's own
-- sensor samples (widgets/dashboard/context.lua).
local function sample(stats, minKey, maxKey, key, value)
  value = tonumber(value)
  if value == nil then return end
  if minKey then
    if stats[minKey] == nil or value < stats[minKey] then stats[minKey] = value end
    if stats[maxKey] == nil or value > stats[maxKey] then stats[maxKey] = value end
  end
  local entry = stats[key]
  if not entry then
    entry = {min = value, max = value, sum = 0, count = 0, avg = value}
    stats[key] = entry
  end
  if value < entry.min then entry.min = value end
  if value > entry.max then entry.max = value end
  entry.sum = entry.sum + value
  entry.count = entry.count + 1
  entry.avg = entry.sum / entry.count
end

local FlightStats = {}
FlightStats.__index = FlightStats

function FlightStats:clear()
  for key in pairs(self.stats) do self.stats[key] = nil end
  self.headspeedVariancePct = nil
end

-- The dashboard's "reset flight" action, and the start state.
function FlightStats:reset()
  self.phase = "preflight"
  self.flown = false
  self.lastArmed = false
  self:clear()
end

function flight_stats.new()
  local self = setmetatable({stats = {}}, FlightStats)
  self:reset()
  return self
end

-- One tick. `s` is the session: connected, isArmed, mcuId, governorState, rxMap,
-- throttlePercent and the recorded values in FIELDS. Returns the phase.
function FlightStats:update(s)
  local previous = self.phase
  local connected = s.connected == true
  local armed = s.isArmed == true
  local mcuId = s.mcuId

  -- A different craft: nothing of the previous one carries over.
  if mcuId ~= self.prevMcuId and connected and mcuId and mcuId ~= "" then
    if self.lastMcuId and self.lastMcuId ~= mcuId then self:reset() end
    self.lastMcuId = mcuId
  end
  -- The link is back: a finished flight is closed, the extremes start empty.
  if connected and not self.prevConnected then
    if previous == "postflight" or previous == "offline" then self:reset() else self:clear() end
  end

  -- In flight: the governor drives the rotors, or the radio's throttle channel
  -- (RX_MAP), or until RX_MAP is known the FC's telemetry throttle, is above 35.
  local flying = false
  if armed and connected then
    local governor = s.governorState
    if type(governor) == "number" and governor >= 4 and governor <= 8 then
      flying = true
    else
      local member = s.rxMap and s.rxMap.throttle
      local value
      if type(member) == "number" then
        if self.throttleMember ~= member then
          self.throttleMember = member
          self.throttleSource = CATEGORY_CHANNEL ~= nil
            and system.getSource({category = CATEGORY_CHANNEL, member = member, options = 0}) or nil
        end
        value = self.throttleSource and self.throttleSource:value()
      end
      if type(value) ~= "number" then value = s.throttlePercent end
      flying = type(value) == "number" and value > 35
    end
  end

  -- `flown` is set exactly while the phase is inflight, postflight or offline.
  local mode
  if self.flown and not connected then
    self.flown = true
    mode = "offline"
  elseif armed and not self.lastArmed then
    self.flown = false
    mode = "armed"
  elseif flying then
    self.flown = true
    mode = "inflight"
  elseif self.flown then
    -- Armed after a flight holds inflight through a gap in the spool-up check.
    mode = armed and "inflight" or "postflight"
  else
    mode = armed and "armed" or "preflight"
  end
  self.lastArmed = armed
  self.phase = mode

  if mode == "inflight" then
    if previous == "preflight" or previous == "armed" then self:clear() end
    local stats = self.stats
    for i = 1, #FIELDS, 4 do
      sample(stats, FIELDS[i + 1], FIELDS[i + 2], FIELDS[i + 3], s[FIELDS[i]])
    end
    local voltage, amps = tonumber(s.voltage), tonumber(s.current)
    if voltage and amps then sample(stats, "minWatts", "maxWatts", "watts", voltage * amps) end
    local rpm, entry = tonumber(s.rpm), stats.rpm
    if rpm and entry and entry.avg > 0 then
      self.headspeedVariancePct = math.floor(math.abs(rpm - entry.avg) / entry.avg * 100 + 0.5)
    end
  end

  self.prevConnected = connected
  self.prevMcuId = mcuId
  return mode
end

flight_stats.sample = sample

-- The layout a phase draws with: armed draws preflight, offline draws postflight.
function flight_stats.layoutPhase(mode)
  if mode == "armed" then return "preflight" end
  if mode == "offline" then return "postflight" end
  return mode
end

package.loaded["rfsuite.lib.flight_stats"] = flight_stats
return flight_stats
