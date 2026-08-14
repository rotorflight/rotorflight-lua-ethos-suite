-- Servos submenu gate: BUS output is only valid when Ports has an
-- SBUS/FBUS output function configured.

local requireModule = assert(loadfile("lib/require.lua"))()
local bus = requireModule("lib/bus.lua")
local serialConfig = requireModule("lib/msp_serial_config.lua")

local servo_bus_guard = {}

local REQUEST_TIMEOUT = 3.0
local FUNCTION_MASK_SBUS_OUT = 262144
local FUNCTION_MASK_FBUS_OUT = 524288
local BUS_FUNCTION_MASK = FUNCTION_MASK_SBUS_OUT + FUNCTION_MASK_FBUS_OUT

local function maskHasAny(mask, bits)
  if bits == 0 then return false end
  local bit = 1
  while bits > 0 do
    if bits % 2 == 1 and math.floor((mask or 0) / bit) % 2 == 1 then
      return true
    end
    bits = math.floor(bits / 2)
    bit = bit * 2
  end
  return false
end

local function portsHaveServoBus(ports)
  ports = ports or {}
  for i = 1, #ports do
    if maskHasAny(ports[i] and ports[i].function_mask, BUS_FUNCTION_MASK) then
      return true
    end
  end
  return false
end

function servo_bus_guard.new(opts)
  opts = opts or {}

  local state = {
    token = 0,
    attempted = false,
    pending = false,
    ready = false,
    busEnabled = false,
    deadline = nil,
    dirty = true,
  }

  local function canRequest()
    if opts.canRequest then return opts.canRequest() == true end
    return true
  end

  local function setResult(enabled, ready)
    state.busEnabled = enabled == true
    state.ready = ready == true
    state.pending = false
    state.deadline = nil
    state.dirty = true
  end

  local function request()
    if state.attempted or state.pending or not canRequest() then return end

    state.attempted = true
    state.pending = true
    state.ready = false
    state.busEnabled = false
    state.deadline = os.clock() + REQUEST_TIMEOUT
    state.dirty = true
    state.token = state.token + 1
    local token = state.token

    bus.publish("msp.request", serialConfig.buildReadMessage(function(data)
      if token ~= state.token then return end
      setResult(portsHaveServoBus(data and data.ports), true)
    end, function()
      if token ~= state.token then return end
      setResult(false, false)
    end))
  end

  local guard = {}

  function guard.open()
    state.token = state.token + 1
    state.attempted = false
    state.pending = false
    state.ready = false
    state.busEnabled = false
    state.deadline = nil
    state.dirty = true
    request()
  end

  function guard.close()
    state.token = state.token + 1
    state.pending = false
    state.deadline = nil
  end

  function guard.wakeup()
    if not canRequest() then
      if state.attempted or state.pending or state.ready or state.busEnabled then
        state.token = state.token + 1
        state.attempted = false
        state.pending = false
        state.ready = false
        state.busEnabled = false
        state.deadline = nil
        state.dirty = true
      end
    end

    request()

    if state.pending and state.deadline ~= nil and os.clock() >= state.deadline then
      setResult(false, false)
    end

    local dirty = state.dirty
    state.dirty = false
    return dirty
  end

  function guard.isEntryEnabled(entry)
    if not (entry and entry.requiresServoBus == true) then return true end
    return state.ready == true and state.busEnabled == true
  end

  return guard
end

return servo_bus_guard
