-- ESC forward-programming menu gate, based on MSP_ESC_SENSOR_CONFIG.protocol.

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local bus = requireModule("lib/bus.lua")
local escSensorConfig = requireModule("lib/msp_esc_sensor_config.lua")

local esc_protocol_guard = {}

local REQUEST_TIMEOUT = 3.0

-- How long to wait after a failed read before trying again. Without it,
-- wakeup() issues a new request on every tick.
local RETRY_INTERVAL = 5.0

local function isSimulation()
  local version = system and system.getVersion and system.getVersion()
  return version and version.simulation == true
end

local function normalizeProtocolIds(raw)
  if type(raw) == "number" then
    return {math.floor(raw)}
  end
  if type(raw) ~= "table" then
    return nil
  end

  local ids = {}
  for i = 1, #raw do
    local value = tonumber(raw[i])
    if value ~= nil then
      ids[#ids + 1] = math.floor(value)
    end
  end
  if #ids == 0 then return nil end
  return ids
end

function esc_protocol_guard.new(opts)
  opts = opts or {}

  local state = {
    token = 0,
    attempted = false,
    pending = false,
    ready = false,
    protocol = nil,
    deadline = nil,
    nextAttemptAt = 0,
    dirty = true,
  }

  local function canRequest()
    if isSimulation() then return false end
    if opts.canRequest then return opts.canRequest() == true end
    return true
  end

  local function setResult(protocol, ready)
    state.protocol = protocol
    state.ready = ready == true
    state.attempted = (ready == true)
    state.pending = false
    state.deadline = nil
    state.nextAttemptAt = 0
    state.dirty = true
  end

  -- A read that did not produce a usable result must not latch the guard shut.
  -- `attempted` used to mean both "it is in flight" (for which there is
  -- `pending`) and "we have read already" (for which the flag belongs back to
  -- false after a failure). Without that, one hiccup leaves the tile grey until
  -- the next open(), even if the FC is healthy by then. See #2387.
  local function fail()
    state.protocol = nil
    state.ready = false
    state.pending = false
    state.deadline = nil
    state.attempted = false
    state.nextAttemptAt = os.clock() + RETRY_INTERVAL
    state.dirty = true
  end

  local function request()
    if state.attempted or state.pending or state.ready or not canRequest() then return end
    if os.clock() < state.nextAttemptAt then return end

    state.attempted = true
    state.pending = true
    state.ready = false
    state.protocol = nil
    state.deadline = os.clock() + REQUEST_TIMEOUT
    state.dirty = true
    state.token = state.token + 1
    local token = state.token

    bus.publish("msp.request", escSensorConfig.buildReadMessage(function(data)
      if token ~= state.token then return end
      local protocol = tonumber(data and data.protocol)
      if protocol == nil then
        fail()
      else
        -- Protocol 0 ("NONE") is a valid result: the FC answered and there
        -- are no ESCs. That is an answer, not a failure -- so `attempted`
        -- stays set here and nothing is read again.
        setResult(math.floor(protocol), true)
      end
    end, function()
      if token ~= state.token then return end
      fail()
    end))
  end

  local guard = {}

  function guard.open()
    state.token = state.token + 1
    state.attempted = false
    state.pending = false
    state.ready = isSimulation()
    state.protocol = nil
    state.deadline = nil
    state.nextAttemptAt = 0
    state.dirty = true
    request()
  end

  function guard.close()
    state.token = state.token + 1
    state.pending = false
    state.deadline = nil
  end

  function guard.wakeup()
    if isSimulation() then
      if state.ready ~= true or state.pending then
        state.ready = true
        state.pending = false
        state.deadline = nil
        state.dirty = true
      end
    elseif not canRequest() then
      if state.attempted or state.pending or state.ready or state.protocol ~= nil or state.nextAttemptAt > 0 then
        state.token = state.token + 1
        state.attempted = false
        state.pending = false
        state.ready = false
        state.protocol = nil
        state.deadline = nil
        -- The link is gone, so any backoff armed for it is meaningless: the
        -- next request after the link returns should not have to wait it out.
        state.nextAttemptAt = 0
        state.dirty = true
      end
    end

    request()

    if state.pending and state.deadline ~= nil and os.clock() >= state.deadline then
      fail()
    end

    local dirty = state.dirty
    state.dirty = false
    return dirty
  end

  function guard.isEntryEnabled(entry)
    if isSimulation() then return true end

    local ids = normalizeProtocolIds(entry and (entry.escProtocolIds or entry.escProtocolId))
    if ids == nil then return true end
    if state.ready ~= true or state.protocol == nil then return false end

    for i = 1, #ids do
      if ids[i] == state.protocol then return true end
    end
    return false
  end

  return guard
end

return esc_protocol_guard
