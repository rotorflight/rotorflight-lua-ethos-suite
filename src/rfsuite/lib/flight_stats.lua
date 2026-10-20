-- Flight phase and flight extremes, owned by the session (#2344).
--
-- The session calls update(session, read) every tick, so the phase and the extremes
-- are kept whether a dashboard is open or not. `read` is lib/live_sensors.lua's
-- read(): the same sensor values the dashboard shows. The dashboard and the ActiveLook widget
-- only read the result from the session snapshot (`flightState`, `flight`).
--
-- Phases: preflight, armed, inflight, postflight, offline. The rules are the ones the
-- dashboard used to apply itself (its tracker plus the reconnect and craft-change
-- resets around it).

local flight_stats = {}

local STAT_SUFFIXES = {
  rssi = "Rssi",
  link = "Link",
  vfr = "Vfr",
  voltage = "Voltage",
  cell_voltage = "CellVoltage",
  consumption = "Consumption",
  smartconsumption = "Consumption",
  current = "Current",
  throttle_percent = "ThrottlePercent",
  rpm = "Rpm",
  headspeed = "Rpm",
  tailspeed = "Tailspeed",
  smartfuel = "FuelPercent",
  fuel = "FuelPercent",
  temp_mcu = "TempMcu",
  temp_esc = "TempEsc",
  bec_voltage = "BecVoltage",
  altitude = "Altitude",
  watts = "Watts",
}

local STAT_ALIASES = {
  headspeed = "rpm",
  smartconsumption = "consumption",
  fuel = "smartfuel",
}

local PRESENTATION_STAT_SOURCES = {
  "voltage",
  "cell_voltage",
  "current",
  "consumption",
  "smartconsumption",
  "throttle_percent",
  "rpm",
  "headspeed",
  "tailspeed",
  "link",
  "rssi",
  "vfr",
  "smartfuel",
  "fuel",
  "temp_mcu",
  "temp_esc",
  "bec_voltage",
  "altitude",
  "watts",
  "esc_load",
}

-- The entry key for a sensor name: an alias shares the entry of the name it stands for.
local function statKey(name)
  return STAT_ALIASES[name or ""] or name
end

-- Sampled every in-flight tick, three slots per sensor: name, min key, max key (false
-- where the sensor has no flat min/max). Built once here, so a tick allocates no key
-- strings. An alias reads the same value as the name it stands for, so it is skipped.
local ROWS = {}
for _, name in ipairs(PRESENTATION_STAT_SOURCES) do
  if not STAT_ALIASES[name] then
    local suffix = STAT_SUFFIXES[name]
    ROWS[#ROWS + 1] = name
    ROWS[#ROWS + 1] = suffix and ("min" .. suffix) or false
    ROWS[#ROWS + 1] = suffix and ("max" .. suffix) or false
  end
end

-- One value into the extremes: flat min/max keys (when given) and the
-- {min, max, sum, count, avg} entry under `key`. Shared with the dashboard's own
-- sensor samples (widgets/dashboard/context.lua).
-- `noMin` leaves both minima out: those are taken by the powered gate below.
local function sample(stats, minKey, maxKey, key, value, noMin)
  value = tonumber(value)
  if value == nil then return end
  if minKey then
    if not noMin and (stats[minKey] == nil or value < stats[minKey]) then stats[minKey] = value end
    if stats[maxKey] == nil or value > stats[maxKey] then stats[maxKey] = value end
  end
  local entry = stats[key]
  if not entry then
    entry = {min = (not noMin) and value or nil, max = value, sum = 0, count = 0, avg = value}
    stats[key] = entry
  end
  if not noMin and value < entry.min then entry.min = value end
  if value > entry.max then entry.max = value end
  entry.sum = entry.sum + value
  entry.count = entry.count + 1
  entry.avg = entry.sum / entry.count
end

-- The powered gate for the minima of headspeed and current (#2344), as the EdgeTX suite's
-- flight record has it (tasks/events/telemetry/flight_record.lua, EdgeTX PR #384).
--
-- A minimum taken over the whole flight phase is the minimum of the spool-up and the
-- spool-down: the first readings after arming are the lowest of the flight, and minimum
-- current reads 0 A. So these two minima are only taken while the rotor is under power.
-- The maxima, and every other value, keep the whole flight phase.
--
-- With the FC's governor state, "under power" is ACTIVE (4) or BYPASS (9) held for 2 s. The
-- state is trusted once a value in its own range has been seen in this flight; without it
-- (governor off, or the sensor not sent) the head has to turn (>= 100 rpm) and be driven
-- (throttle >= 25 % or current >= 1.5 A) for 2 s, and the minimum is offered the reading of
-- 2 s ago, so the last 2 s of a driven stretch -- a spool-down, a bogging head -- never count.
-- The gate runs on the EdgeTX cadence of 0.5 s, so the hold and the delay are the same there.
local POWERED_GOVERNOR_STATE = {[4] = true, [9] = true}
local SPINNING_RPM = 100
local DRIVEN_THROTTLE_PERCENT = 25
local DRIVEN_CURRENT = 1.5
local GATE_INTERVAL = 0.5
local POWERED_HOLD_SAMPLES = 4
local POWERED_TAIL_SAMPLES = 4

-- Offers one minimum through the gate. `line` holds the last four gate samples of this
-- sensor; without a governor state the value offered is the one of four samples ago.
local function offerMin(self, line, key, minKey, value, positive)
  value = tonumber(value)
  if value == nil then return end
  if not self.govStateSeen then
    value, line[1], line[2], line[3], line[4] = line[1], line[2], line[3], line[4], value
  end
  if not self.powered or value == nil or (positive and value <= 0) then return end
  local stats = self.stats
  if stats[minKey] == nil or value < stats[minKey] then stats[minKey] = value end
  local entry = stats[key]
  if entry and (entry.min == nil or value < entry.min) then entry.min = value end
end

local FlightStats = {}
FlightStats.__index = FlightStats

function FlightStats:clear()
  for key in pairs(self.stats) do self.stats[key] = nil end
  self.headspeedVariancePct = nil
  self.govStateSeen = false
  self.poweredSamples = 0
  self.powered = false
  self.gateAt = nil
end

-- The dashboard's "reset flight" action, and the start state.
function FlightStats:reset()
  self.phase = "preflight"
  self.flown = false
  self.lastArmed = false
  self:clear()
end

function flight_stats.new()
  local self = setmetatable({stats = {}, rpmLine = {}, currentLine = {}}, FlightStats)
  self:reset()
  return self
end

-- One tick. `s` is the session: connected, isArmed, mcuId, governorState, rxMap,
-- throttlePercent and the fields `read` takes its values from. Returns the phase.
function FlightStats:update(s, read, now)
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
    local stats, rpm, current, throttle = self.stats, nil, nil, nil
    for i = 1, #ROWS, 3 do
      local name = ROWS[i]
      local value = read(s, name)
      local gated = name == "rpm" or name == "current"
      sample(stats, ROWS[i + 1], ROWS[i + 2], name, value, gated)
      if name == "rpm" then rpm = tonumber(value)
      elseif name == "current" then current = tonumber(value)
      elseif name == "throttle_percent" then throttle = tonumber(value) end
    end

    now = now or os.clock()
    if self.gateAt == nil or now >= self.gateAt then
      self.gateAt = now + GATE_INTERVAL
      local governor = tonumber(s.governorState)
      if governor and governor >= 1 and governor <= 9 then self.govStateSeen = true end
      local gate, need
      if self.govStateSeen then
        gate = POWERED_GOVERNOR_STATE[governor] == true
        need = POWERED_HOLD_SAMPLES
      else
        gate = (rpm or 0) >= SPINNING_RPM
          and ((throttle or 0) >= DRIVEN_THROTTLE_PERCENT or (current or 0) >= DRIVEN_CURRENT)
        need = POWERED_HOLD_SAMPLES + POWERED_TAIL_SAMPLES
      end
      self.poweredSamples = gate and self.poweredSamples + 1 or 0
      self.powered = self.poweredSamples >= need
      offerMin(self, self.rpmLine, "rpm", "minRpm", rpm, true)
      offerMin(self, self.currentLine, "current", "minCurrent", current, false)
    end
    local entry = stats.rpm
    if rpm and entry and entry.avg > 0 then
      self.headspeedVariancePct = math.floor(math.abs(rpm - entry.avg) / entry.avg * 100 + 0.5)
    end
  end

  self.prevConnected = connected
  self.prevMcuId = mcuId
  return mode
end

flight_stats.sample = sample
flight_stats.statKey = statKey
flight_stats.STAT_SUFFIXES = STAT_SUFFIXES

-- The layout a phase draws with: armed draws preflight, offline draws postflight.
function flight_stats.layoutPhase(mode)
  if mode == "armed" then return "preflight" end
  if mode == "offline" then return "postflight" end
  return mode
end

package.loaded["rfsuite.lib.flight_stats"] = flight_stats
return flight_stats
