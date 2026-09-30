-- Local flight timer state owned by the background task.

local flight_timer = {}

-- A flight counts towards stats.flightcount once it has run this long.
local FLIGHT_COUNT_SECONDS = 25

-- How long a link loss may last and still be called the same flight. Past
-- this the record is closed and the next armed tick opens a new one.
--
-- The window bounds *merging*, never splitting: a gap that outlasts it yields
-- two records instead of one wrong record, because two flights merged into one
-- corrupt the peak values and the flight count, while one flight split in two
-- only costs a file boundary.
local RECONNECT_GRACE_SECONDS = 30

local state = {
  start = nil,
  live = 0,
  session = 0,
  flightCounted = false,
  -- The session total at the moment the current flight began. A flight's own
  -- time is session - flightBase, which stays correct across a link loss where
  -- a plain segment would not.
  flightBase = 0,
  -- Set when a flight was in progress when the link dropped. The segment is
  -- already folded into `session`; this is what makes it resumable.
  resumable = false,
  lostAt = nil,
}

local function roundedSeconds(value)
  value = tonumber(value) or 0
  if value < 0 then value = 0 end
  return math.floor(value + 0.5)
end

local function snapshot()
  return {
    timerLive = roundedSeconds(state.live),
    timerSession = roundedSeconds(state.session),
    timerFlightCounted = state.flightCounted == true,
  }
end

local function sameSnapshot(a, b)
  return a.timerLive == b.timerLive
    and a.timerSession == b.timerSession
    and a.timerFlightCounted == b.timerFlightCounted
end

local function elapsedSince(start, now)
  local segment = now - start
  if segment < 0 then segment = 0 end
  return segment
end

-- Time of the flight currently open, not of the whole session.
local function currentFlightTime()
  return state.session - state.flightBase
end

function flight_timer.reset()
  state.start = nil
  state.live = 0
  state.session = 0
  state.flightCounted = false
  state.flightBase = 0
  state.resumable = false
  state.lostAt = nil
end

-- Fold the running segment into the session total and stop the clock without
-- reporting a finished segment: the flight has not ended, the link has.
local function freeze(now)
  if not state.start then return end
  state.session = state.session + elapsedSince(state.start, now)
  state.start = nil
  state.live = state.session
  state.resumable = true
  state.lostAt = now
end

-- Close the open flight for good, so the next arming opens a new record.
-- Returns the event the caller persists, or nil when there was nothing to close.
-- The running segment is banked first, so a flight that was held open across a
-- link loss reports the whole flight and not just the part before the drop.
local function closeFlight(now)
  if state.start then
    state.session = state.session + elapsedSince(state.start, now)
    state.start = nil
  end
  local flown = currentFlightTime()
  local event = nil
  if flown > 0 then
    event = {
      finishedSegment = roundedSeconds(flown),
      session = roundedSeconds(state.session),
    }
  end
  state.flightBase = state.session
  state.resumable = false
  state.lostAt = nil
  state.live = state.session
  return event
end

-- A step can both close an abandoned flight and open a new one, so the two
-- facts have to share one event rather than the second overwriting the first.
local function addEvent(existing, extra)
  if not extra then return existing end
  if not existing then return extra end
  for k, v in pairs(extra) do existing[k] = v end
  return existing
end

function flight_timer.update(connected, armed, now)
  local before = snapshot()
  now = tonumber(now) or os.clock()
  local event = nil

  if connected ~= true then
    if state.start then
      -- Mid-flight link loss: hold the flight open across the gap. The time
      -- flown so far is already banked in `session`, and flightCounted survives,
      -- so a drop past the count threshold cannot be counted as a second flight.
      freeze(now)
    elseif state.resumable then
      if (now - state.lostAt) > RECONNECT_GRACE_SECONDS then
        event = addEvent(event, closeFlight(now))
      end
    elseif not state.resumable then
      -- Nothing was running and nothing is being held open, so there is nothing
      -- to keep. The `resumable` arm matters: the link usually stays down for
      -- many ticks, and a second one must not wipe the flight being held.
      flight_timer.reset()
    end
  elseif armed == true then
    if state.resumable then
      if (now - state.lostAt) <= RECONNECT_GRACE_SECONDS then
        -- Same flight. `session` already carries the time flown before the
        -- drop, so the clock restarts from here on top of it.
        state.resumable = false
        state.lostAt = nil
        state.start = now
      else
        -- Too long gone to call it the same flight. Close what was there --
        -- it was a real flight and its time is already banked -- and begin a
        -- new record from here.
        event = addEvent(event, closeFlight(now))
        state.start = now
        state.flightBase = state.session
        state.flightCounted = false
      end
    elseif not state.start then
      state.start = now
      state.flightCounted = false
      state.flightBase = state.session
    end
    -- Measured from the start of the flight, not from the start of the current
    -- leg: a flight held open across a link loss is already partly flown, and
    -- testing only this leg would let one flight be counted twice.
    local flown = state.session - state.flightBase + elapsedSince(state.start, now)
    state.live = state.flightBase + flown
    if flown >= FLIGHT_COUNT_SECONDS and not state.flightCounted then
      state.flightCounted = true
      event = addEvent(event, {flightCounted = true})
    end
  elseif armed == false then
    -- Disarmed while connected, or reconnected into a disarmed state: either
    -- way the flight is over, including one that was held open across a drop.
    if state.start or state.resumable then
      event = addEvent(event, closeFlight(now))
    end
    state.live = state.session
  else
    -- armed is nil (link is connected, but arming state has not been received yet):
    -- hold the flight while resumable unless grace has expired.
    if state.resumable and (now - state.lostAt) > RECONNECT_GRACE_SECONDS then
      event = addEvent(event, closeFlight(now))
    end
    state.live = state.session
  end

  local after = snapshot()
  return not sameSnapshot(before, after), after, event
end

-- True while a flight that was in progress at link loss can still be resumed.
-- The log writer needs exactly this to decide between holding its file open
-- and starting a new one, so the grace window is decided in one place.
function flight_timer.resumable(now)
  if not state.resumable then return false end
  now = tonumber(now) or os.clock()
  return (now - state.lostAt) <= RECONNECT_GRACE_SECONDS
end

-- True while a flight is actively running or held open across a link loss.
function flight_timer.inProgress(now)
  return state.start ~= nil or flight_timer.resumable(now)
end

function flight_timer.current()
  return snapshot()
end

return flight_timer
