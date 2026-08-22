-- Old dashboard flight-status state machine, adapted for Lite widget state.
--
-- inFlight()'s throttle check used to read the *radio's own* throttle
-- channel directly (pre-rewrite tasks/scheduler/events/tasks/flightmode.lua:
-- `rfsuite.session.rx.values.throttle`, via
-- system.getSource({category = CATEGORY_CHANNEL, member = <RX_MAP throttle
-- index>})) -- a local signal, always current, independent of the aircraft.
-- The "Total rewrite" (#2256) swapped that for the FC's own telemetry-
-- reported throttle_percent sensor (tasks/session.lua), because the RX_MAP
-- fetch (lib/msp_rx_map.lua) hadn't been ported yet -- see
-- lib/msp_handshake.lua's own "Deliberately excludes rxmap" comment. That
-- swap is what's being undone here: a telemetry sensor has to actually be
-- broadcast and resolved over the link, and (self-caught live) simply
-- doesn't behave the same as raw stick position once the governor is off --
-- the dashboard could get stuck showing "postflight" after a rearm because
-- throttle_percent never convincingly crossed THROTTLE_THRESHOLD again.
-- resolveThrottleChannelValue() below restores the original radio-channel
-- read (session.rxMap, fetched once per connect by tasks/session.lua),
-- falling back to the telemetry sensor only if RX_MAP hasn't resolved yet
-- (older FC, or still mid-handshake) rather than never detecting flight.
--
-- Tracker:update() also restores two rules the rewrite dropped from the
-- same pre-rewrite determineMode(): resetting to "preflight" on a fresh
-- disarmed->armed edge (rather than carrying over whatever the previous
-- flight left in `current`), and holding "inflight" for as long as the
-- aircraft stays armed once a flight has genuinely started, so a momentary
-- gap in the spool-up check doesn't bounce the dashboard to "postflight"
-- mid-flight -- see that function's own comment.

if package.loaded["rfsuite.widgets.dashboard.flightmode"] then
  return package.loaded["rfsuite.widgets.dashboard.flightmode"]
end

local flightmode = {}

local THROTTLE_THRESHOLD = 35

local function isGovernorActive(value)
  return type(value) == "number" and value >= 4 and value <= 8
end

-- Resolves (and caches, on the widget itself) a Source for the radio's own
-- throttle channel, keyed off session.rxMap.throttle (the physical channel
-- index reported by MSP_RX_MAP -- see lib/msp_rx_map.lua). Re-resolves only
-- when that index changes (a different craft's RX_MAP fetched on
-- reconnect); the resolved Source itself is transmitter-side and stays
-- valid across reconnects to the *same* channel index, so it's fine to
-- reuse. Returns nil (not 0) whenever the channel can't be read yet, so
-- callers can tell "no data" apart from "stick at low end".
local function resolveThrottleChannelValue(widget)
  local rxMap = widget.rxMap
  local member = rxMap and rxMap.throttle
  if type(member) ~= "number" then return nil end

  if widget._throttleChannelMember ~= member then
    if system and system.getSource and CATEGORY_CHANNEL ~= nil then
      widget._throttleChannelSource = system.getSource({category = CATEGORY_CHANNEL, member = member, options = 0})
    else
      widget._throttleChannelSource = nil
    end
    widget._throttleChannelMember = member
  end

  local source = widget._throttleChannelSource
  if not source then return nil end
  local value = source:value()
  if type(value) ~= "number" then return nil end
  return value
end

local function inFlight(widget)
  if not widget or widget.isArmed ~= true or widget.connected ~= true then return false end
  if isGovernorActive(widget.governorState) then return true end

  local channelThrottle = resolveThrottleChannelValue(widget)
  if channelThrottle ~= nil then
    return channelThrottle > THROTTLE_THRESHOLD
  end

  -- RX_MAP not resolved yet -- fall back to the FC's own telemetry-reported
  -- throttle_percent rather than never detecting flight at all.
  local throttle = widget.throttlePercent
  return type(throttle) == "number" and throttle > THROTTLE_THRESHOLD
end

local Tracker = {}
Tracker.__index = Tracker

function Tracker:reset()
  self.current = "preflight"
  self.lastFlightMode = nil
  self.hasBeenInFlight = false
  self.lastArmed = false
end

function Tracker:update(widget)
  widget = widget or {}
  local connected = widget.connected == true
  local armed = widget.isArmed == true
  local current = self.current or "preflight"
  local mode

  if (current == "inflight" or current == "postflight") and not connected then
    self.hasBeenInFlight = true
    mode = "postflight"
  elseif armed and not self.lastArmed then
    -- Fresh disarmed->armed edge: start this flight's own detection over
    -- rather than carrying over the previous flight's hasBeenInFlight, so
    -- a rearm doesn't depend on inFlight(widget) already reading true on
    -- this exact tick to leave "postflight".
    self.hasBeenInFlight = false
    mode = "preflight"
  elseif inFlight(widget) then
    self.hasBeenInFlight = true
    mode = "inflight"
  elseif armed and self.hasBeenInFlight then
    -- Hold "inflight" while still armed even if this tick's spool-up check
    -- momentarily reads false -- a transient channel/telemetry gap must not
    -- flip the dashboard to "postflight" mid-flight.
    mode = "inflight"
  elseif self.hasBeenInFlight then
    mode = "postflight"
  else
    mode = "preflight"
  end

  self.lastArmed = armed
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
