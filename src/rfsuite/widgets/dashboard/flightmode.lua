-- Old dashboard flight-status state machine, adapted for Lite widget state.

if package.loaded["rfsuite.widgets.dashboard.flightmode"] then
  return package.loaded["rfsuite.widgets.dashboard.flightmode"]
end

local flightmode = {}

local THROTTLE_THRESHOLD = 35

local function isGovernorActive(value)
  return type(value) == "number" and value >= 4 and value <= 8
end

local function inFlight(widget)
  if not widget or widget.isArmed ~= true or widget.connected ~= true then return false end
  if isGovernorActive(widget.governorState) then return true end
  local throttle = widget.throttlePercent
  return type(throttle) == "number" and throttle > THROTTLE_THRESHOLD
end

local Tracker = {}
Tracker.__index = Tracker

function Tracker:reset()
  self.current = "preflight"
  self.lastFlightMode = nil
  self.hasBeenInFlight = false
end

function Tracker:update(widget)
  widget = widget or {}
  local connected = widget.connected == true
  local current = self.current or "preflight"
  local mode

  if (current == "inflight" or current == "postflight") and not connected then
    self.hasBeenInFlight = true
    mode = "postflight"
  elseif inFlight(widget) then
    self.hasBeenInFlight = true
    mode = "inflight"
  elseif self.hasBeenInFlight then
    mode = "postflight"
  else
    mode = "preflight"
  end

  self.current = mode
  return mode
end

function flightmode.new()
  local tracker = setmetatable({}, Tracker)
  tracker:reset()
  return tracker
end

package.loaded["rfsuite.widgets.dashboard.flightmode"] = flightmode
return flightmode
