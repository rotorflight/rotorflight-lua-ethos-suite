-- Tune Advisor capture, owned by the background task.
--
-- The FC measures the rate loop while you fly (lib/msp_tune_advisor.lua) but
-- keeps it in RAM. On each disarm this reads all three axes, saves them as
-- one flight (lib/tune_history.lua: the last few flights per aircraft), then
-- clears the FC so the next flight is measured on its own. The Tune Advisor
-- page works from the saved flights, not from the FC.
--
-- Event-driven from "session.update", no scheduler job: a capture is armed
-- by a disarm and runs once the link and aircraft identity are there, so a
-- flight that ends during a link loss is still captured on reconnect (the
-- FC kept the numbers). Nothing is saved for a flight with no rate flight
-- (flight_seconds 0). If the clear never gets through before the next arm,
-- that next flight's row also holds this one's data: the FC cannot tell.
--
-- Paced so telemetry keeps flowing. Over S.Port and FBUS each 65-byte reply
-- takes about 15 telemetry frames, every one a sensor frame the FC does not
-- send, and the FC then holds sensors back for another 250 ms after the last
-- one. Read back to back, and retried every few seconds when a reply is lost,
-- that kept current, ESC and other sensors off the radio for as long as the
-- model sat disarmed. So the first read waits START_SECONDS after the disarm
-- (the pilot is reading the landing numbers, and the flight-stats sync goes
-- first), each later request waits GAP_SECONDS, a failed axis is asked again
-- on its own, and after MAX_FAILURES link errors the capture waits for the
-- next disarm. The FC keeps the numbers, so that disarm still saves them.
--
-- Publishes "tune_history.state" (retained, see lib/bus.lua) whenever it
-- changes, so the Tune Advisor page can hold its advice until the flight is in:
--   "reading"  disarmed with this flight not saved yet, or its clear still to go
--   "failed"   gave up after MAX_FAILURES; the next disarm reads it
--   "idle"     anything else
--
-- Clocked by tasks/background.lua's scheduler (wakeup(), every 0.5 s), not by
-- "session.update" alone: the session publishes only when its snapshot
-- changes, so a quiet bench, or exactly the sensor dropout this pacing is
-- about, could leave a wait that never ends. "session.update" only records
-- the arm state, link and aircraft.
local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local bus = requireModule("lib/bus.lua")
local tuneAdvisor = requireModule("lib/msp_tune_advisor.lua")
local tuneHistory = requireModule("lib/tune_history.lua")

local START_SECONDS = 5           -- after a disarm, before the first read
local GAP_SECONDS = 2             -- between one answered request and the next
local RETRY_SECONDS = 5           -- after a link error, before asking again
local MAX_FAILURES = 3            -- link errors per disarm before waiting for the next one

local lastArmed = nil             -- last known arm state; a link loss (nil) keeps it
local pending = false             -- a disarm has not been captured yet
local clearPending = false        -- saved, the FC not cleared yet
local busy = false                -- a request is out
local refusedOnFc = false         -- the FC holds a flight this layout refused: no clear, it would erase that flight
local nextAt = 0                  -- no request before this os.clock()
local failures = 0                -- link errors since the last disarm
local capture = {mcuId = nil, modelName = nil, replies = {}}
-- The latest session snapshot's fields this task reads, copied rather than
-- holding on to the snapshot table
local link = {armed = nil, connected = false, mcuId = nil, apiVersionSupported = nil, craftName = nil,
  fcVersion = nil, support = nil}
local lastSeconds = {}            -- by mcuId: flight_seconds of the last flight saved
local state = nil                 -- last "tune_history.state" published

local function publishState()
  local now
  if lastArmed ~= false then
    now = "idle"
  elseif pending then
    now = nextAt == math.huge and "failed" or "reading"
  elseif clearPending and not refusedOnFc and nextAt ~= math.huge then
    now = "reading"
  else
    now = "idle"
  end
  if now ~= state then
    state = now
    bus.publish("tune_history.state", now)
  end
end

local function modelName()
  if link.craftName and link.craftName ~= "" then return link.craftName end
  if model and model.name then
    local ok, name = pcall(model.name)
    if ok and name and name ~= "" then return name end
  end
  return "Unknown"
end

local function clearReplies()
  for i = #capture.replies, 1, -1 do capture.replies[i] = nil end
end

local function waitFor(seconds)
  busy = false
  nextAt = os.clock() + seconds
end

-- A link error, or replies that are not one flight. After MAX_FAILURES,
-- nothing more until the next disarm resets the count.
local function failed()
  failures = failures + 1
  if failures >= MAX_FAILURES then
    busy = false
    nextAt = math.huge
    return
  end
  waitFor(RETRY_SECONDS)
end

local function onCleared()
  waitFor(0)
  clearPending = false
  publishState()
end

-- Four answers, and only the last is worth repeating.
--
--   reason == true  the FC's MSP error reply: no tune advisor in this firmware. Nothing
--                   to capture and nothing to clear, so this task stops until the pilot
--                   disarms again.
--   refused == true the FC answered, in a layout this suite does not know (see
--                   lib/msp_tune_advisor.lua's decode). Deterministic: the same reply comes
--                   back on every request, so RETRY_SECONDS would buy nothing but three
--                   reads every five seconds for as long as the model sits disarmed and
--                   connected. This flight is therefore not captured, said so once, and the
--                   NEXT disarm asks again -- once. `clearPending` is left alone on purpose:
--                   the flight controller holds a real flight in this case, and dropping it
--                   to save the retries would throw away data this suite could read once it
--                   knows the layout.
--   "cleared"       the queue was emptied (arming, a link loss, a transport change). Not
--                   this request's fault, so not counted against MAX_FAILURES. The axes
--                   already read are dropped: the FC may have restarted, and its next
--                   answers would be another flight's.
--   anything else   the link. Asked again shortly, from the axis that failed; the axes
--                   already read are kept.
local function handleError(reason, refused)
  if reason == true then
    clearReplies()
    busy = false
    pending = false
    clearPending = false
    return
  end
  if refused then
    clearReplies()
    busy = false
    pending = false
    refusedOnFc = true
    print("[tune_history] reply refused, flight not captured: " .. tostring(reason))
    return
  end
  if reason == "cleared" then
    clearReplies()
    waitFor(RETRY_SECONDS)
    return
  end
  failed()
end

local function onError(reason, refused)
  handleError(reason, refused)
  publishState()
end

local function sendClear()
  busy = true
  bus.publish("msp.request", tuneAdvisor.buildClearMessage(onCleared, onError))
end

local onData

local function requestAxis(axis)
  busy = true
  bus.publish("msp.request", tuneAdvisor.buildReadMessage(axis, onData, onError))
end

-- All three axes are in: save them as one flight, then clear the FC.
local function finishCapture()
  local replies = capture.replies
  local mcuId, seconds = capture.mcuId, replies[1].seconds
  -- One flight has one flight time on every axis. Anything else is an FC that
  -- restarted or flew between two reads: start again.
  for i = 2, #replies do
    if replies[i].seconds ~= seconds then
      clearReplies()
      failed()
      return
    end
  end
  -- 0: no rate flight. Same as last time: the clear after that flight never
  -- got through and nothing new was flown.
  if seconds > 0 and lastSeconds[mcuId] ~= seconds then
    if not tuneHistory.save(mcuId, capture.modelName, replies) then
      -- The replies are kept and only the write is tried again: no MSP, so
      -- not counted against MAX_FAILURES
      print("[tune_history] cannot write " .. tuneHistory.path(mcuId))
      waitFor(RETRY_SECONDS)
      return
    end
    lastSeconds[mcuId] = seconds
    bus.publish("tune_history.saved", mcuId)
  end
  clearReplies()
  pending = false
  if seconds > 0 then clearPending = true end
  waitFor(GAP_SECONDS)
end

onData = function(data)
  local replies = capture.replies
  replies[#replies + 1] = data
  if #replies < tuneAdvisor.AXIS_COUNT then
    waitFor(GAP_SECONDS)
  else
    finishCapture()
  end
  publishState()
end

-- Sends the next request when one is due
local function advance()
  -- Firmware without the Tune Advisor (issue #2579): nothing is sent, and a flight
  -- waiting for capture is dropped. A version not known yet waits, and keeps the
  -- flags, so a flight still in the FC is captured once the version is known.
  if link.support == false then
    pending = false
    clearPending = false
    return
  end
  if link.support ~= true then return end
  if not (pending or clearPending) or busy or link.armed ~= false or link.connected ~= true then return end
  if not link.mcuId or link.apiVersionSupported == false then return end
  if os.clock() < nextAt then return end

  if pending then
    -- Another aircraft since the last answer: its axes, not these
    if #capture.replies > 0 and capture.mcuId ~= link.mcuId then clearReplies() end
    if #capture.replies == 0 then
      refusedOnFc = false
      capture.mcuId = link.mcuId
      capture.modelName = modelName()
    end
    if #capture.replies >= tuneAdvisor.AXIS_COUNT then
      finishCapture()             -- a save that failed, tried again
    else
      requestAxis(#capture.replies + 1)
    end
  elseif not refusedOnFc then
    sendClear()
  end
end

local function onSessionUpdate(snapshot)
  if not snapshot then return end
  local armed = snapshot.isArmed
  if armed == true then
    pending = false               -- the next disarm captures this flight too
  elseif armed == false and lastArmed == true then
    pending = true
    failures = 0
    clearReplies()
    nextAt = os.clock() + START_SECONDS
  end
  if armed ~= nil then lastArmed = armed end
  link.armed = armed
  link.connected = snapshot.connected
  link.mcuId = snapshot.mcuId
  link.apiVersionSupported = snapshot.apiVersionSupported
  link.craftName = snapshot.craftName
  if snapshot.fcVersion ~= link.fcVersion then
    link.fcVersion = snapshot.fcVersion
    link.support = tuneAdvisor.supportFor(link.fcVersion)
  end

  advance()
  publishState()
end

-- tasks/background.lua's scheduler, every 0.5 s
local function wakeup()
  advance()
  publishState()
end

bus.subscribe("session.update", onSessionUpdate)

return {wakeup = wakeup}
