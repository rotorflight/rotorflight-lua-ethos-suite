-- Look up a telemetry sensor's live value by logical name + transport
-- protocol, trying a short list of candidate appIds in order (some
-- ESCs/FCs/firmware versions broadcast the same logical value on a
-- different appId). Stateless -- no module-level state, just a lookup
-- table and pure functions -- the same category of neutral utility as
-- lib/mspcodec.lua.
--
-- Candidate appIds copied from rotorflight-lua-ethos-suite's
-- tasks/scheduler/telemetry/sources/{sport,crsf}.lua, trimmed to only the
-- sensors this rebuild currently needs (voltage, consumption, the
-- firmware-mirrored smartfuel channel, PID/rate/battery profile index,
-- and arm-status flags -- see lib/smartfuel_calc.lua and
-- tasks/session.lua). Add more entries here as more of the original's
-- ~30-sensor table is actually needed; don't port the rest speculatively.
--
-- Self-caught bug: `smartfuel` originally pointed at appId 0x5FE1 for both
-- protocols -- that's actually lib/diy_sensor.lua's own SMARTFUEL_APP_ID,
-- the address the *app itself* fabricates a sensor at when running the
-- local fallback (tasks/session.lua's smartfuelMode == 0 branch), not
-- where the FC's own firmware-computed value is broadcast. Looking that
-- appId up here to decide whether to mirror the firmware is circular --
-- nothing ever broadcasts there natively, so it always resolved to nil and
-- silently disabled fuel% (and the DIY sensor, which only gets created in
-- the *other* branch) whenever smartfuelMode > 0. Corrected to the real
-- firmware-mirror addresses from that same original's own
-- tasks/scheduler/sensors/lib/smartfuelfbl.lua (`mirror_sources`): 0x0600
-- for S.Port, 0x1014 for CRSF. (The original also has a `smartconsumption`
-- channel at the same appId as `consumption` -- not ported here since
-- nothing in this rebuild queries it yet; add it back if that changes.)
-- NOTE: still not independently verified live against real hardware.

-- Per-protocol candidate tables live in their own files (lib/telemetry_
-- sensors_sport.lua / _crsf.lua / _sim.lua) instead of one CANDIDATES
-- literal with all three built in, so only the protocol actually active
-- this session gets loadfile()'d -- tasks/msp/transport_select.lua picks
-- "sport" or "crsf" once at background-task init (no dynamic re-selection),
-- and tasks/session.lua substitutes "sim" for the whole session in the
-- Ethos simulator, so in practice exactly one (occasionally two, see below)
-- of these three ever loads per run, not all three unconditionally.
local CANDIDATE_MODULES = {
  sport = "lib/telemetry_sensors_sport.lua",
  crsf = "lib/telemetry_sensors_crsf.lua",
  sim = "lib/telemetry_sensors_sim.lua",
}

-- false is a valid cached "no such protocol" marker (as opposed to nil,
-- meaning "not attempted yet") so an unknown protocol isn't retried every
-- call.
local loadedCandidates = {}

local function candidatesForProtocol(protocol)
  local loaded = loadedCandidates[protocol]
  if loaded == nil then
    local path = CANDIDATE_MODULES[protocol]
    loaded = (path and assert(loadfile(path))()) or false
    loadedCandidates[protocol] = loaded
  end
  return loaded or nil
end

-- Cache resolved `source` objects per protocol/name so repeated calls
-- (once per wakeup) don't re-scan candidates every time.
local resolvedCache = {}
local missRetryAt = {}
local MISS_RETRY_INTERVAL = 5.0

-- A resolved source is re-latched periodically rather than kept forever.
-- getSource() picks the *first* candidate appId that resolves, which is
-- permanent once cached -- if that first hit is a stale/unwired duplicate
-- sensor (or a slot Ethos discovered before it ever carried a real reading),
-- it was stuck at whatever value() returns (often 0) for the rest of the
-- session, with no path back through the candidate list. Re-running the
-- scan every REVALIDATE_INTERVAL seconds gives a better candidate that
-- shows up later a chance to take over, without rescanning every wakeup.
local revalidateAt = {}
local REVALIDATE_INTERVAL = 8.0

local telemetry_sensors = {}

function telemetry_sensors.getSource(protocol, name)
  local byProtocol = resolvedCache[protocol]
  if not byProtocol then
    byProtocol = {}
    resolvedCache[protocol] = byProtocol
  end

  local now = os.clock()
  local source = byProtocol[name]

  if source then
    local byProtocolRevalidate = revalidateAt[protocol]
    local dueAt = byProtocolRevalidate and byProtocolRevalidate[name]
    if dueAt and now >= dueAt then
      byProtocol[name] = nil
      source = nil
    end
  end

  -- Only a *successful* resolution is cached. A sensor that hasn't started
  -- broadcasting yet (common for consumption/smartfuel right after
  -- connect) must keep being retried, not be written off forever.
  if not source then
    local byProtocolMiss = missRetryAt[protocol]
    if byProtocolMiss and byProtocolMiss[name] and now < byProtocolMiss[name] then
      return nil
    end

    local protocolCandidates = candidatesForProtocol(protocol)
    local candidates = protocolCandidates and protocolCandidates[name]
    if not candidates then return nil end
    for i = 1, #candidates do
      local candidate = system.getSource(candidates[i])
      if candidate then
        source = candidate
        byProtocol[name] = source
        if byProtocolMiss then byProtocolMiss[name] = nil end
        break
      end
    end
    if not source then
      if not byProtocolMiss then
        byProtocolMiss = {}
        missRetryAt[protocol] = byProtocolMiss
      end
      byProtocolMiss[name] = now + MISS_RETRY_INTERVAL
      return nil
    end

    local byProtocolRevalidate = revalidateAt[protocol]
    if not byProtocolRevalidate then
      byProtocolRevalidate = {}
      revalidateAt[protocol] = byProtocolRevalidate
    end
    byProtocolRevalidate[name] = now + REVALIDATE_INTERVAL
  end

  if source.state and source:state() == false then return nil end
  return source
end

function telemetry_sensors.getValue(protocol, name)
  local source = telemetry_sensors.getSource(protocol, name)
  if not source then return nil end
  return source:value()
end

local function clearTable(t)
  for key in pairs(t) do t[key] = nil end
end

function telemetry_sensors.reset()
  clearTable(resolvedCache)
  clearTable(missRetryAt)
  clearTable(revalidateAt)
end

return telemetry_sensors
