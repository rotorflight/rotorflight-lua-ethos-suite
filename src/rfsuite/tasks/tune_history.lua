-- Tune Advisor capture, owned by the background task.
--
-- The FC measures the rate loop while you fly (lib/msp_tune_advisor.lua) but
-- keeps it in RAM. On each disarm this reads all three axes and the two
-- settings the statistics do not carry (Cyclic polarity and ring, I-term relax
-- type: MSP_RC_TUNING and MSP_PID_PROFILE), saves them as one flight
-- (lib/tune_history.lua: the last few flights per aircraft), then clears the FC
-- so the next flight is measured on its own. The Tune Advisor page works from
-- the saved flights, not from the FC.
--
-- Event-driven from "session.update", no scheduler job: a capture is armed
-- by a disarm and runs once the link and aircraft identity are there, so a
-- flight that ends during a link loss is still captured on reconnect to the
-- same aircraft (the FC kept the numbers). The flight is read from the FC of
-- the aircraft that was disarmed, and the clear goes to the FC whose flight
-- was saved: another aircraft connected in between is left alone until the
-- right one is back. Nothing is saved for a flight with no acro flight
-- (flight_seconds 0). If the clear never gets through before the next arm,
-- that next flight's reading also holds this one's data: the FC cannot tell.
-- That reading is then saved marked as containing the saved flight, which the
-- page leaves out rather than counting it twice, when this task can tell
-- (containsHeld): no clear answered and no new link since that save, the same
-- PID and rate profile and tune, more seconds and no count smaller. Nothing
-- saved is ever removed for it; where it cannot tell, both are kept.
--
-- Paced so telemetry keeps flowing. Over S.Port and FBUS each 51-byte reply
-- takes 12 telemetry frames, every one a sensor frame the FC does not
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
--   "unread"   the FC answered in a layout this suite refuses: the flight is held
--              there but not read; the next disarm asks once more
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
local pendingMcu = nil            -- the FC of the aircraft that was disarmed: where its flight is read
local clearMcu = nil              -- the FC whose saved flight is not cleared yet: where the clear goes
local busy = false                -- a request is out
local refusedOnFc = false         -- the FC holds a flight this layout refused: no clear, it would erase that flight
local nextAt = 0                  -- no request before this os.clock()
local failures = 0                -- link errors since the last disarm
local capture = {mcuId = nil, modelName = nil, replies = {}, settings = {}}
-- The latest session snapshot's fields this task reads, copied rather than
-- holding on to the snapshot table
local link = {armed = nil, connected = false, mcuId = nil, mcuIdReady = false, apiVersionSupported = nil, craftName = nil,
  fcVersion = nil, support = nil, pidProfile = nil, rateProfile = nil}
local lastSeconds = {}            -- by mcuId: flight_seconds of the last flight saved
local held = {}                   -- by mcuId: the last flight saved (heldOf), until a clear for it is answered or a new link
local state = nil                 -- last "tune_history.state" published

local function publishState()
  local now
  if lastArmed ~= false then
    now = "idle"
  elseif pending then
    now = nextAt == math.huge and "failed" or "reading"
  elseif refusedOnFc then
    now = "unread"
  elseif clearPending and nextAt ~= math.huge then
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
  for i = #capture.settings, 1, -1 do capture.settings[i] = nil end
end

-- The settings the statistics do not carry (issues #2639, #2640, #2642) are
-- read after the three axes and stored on every axis row of the flight; see
-- lib/tune_history_settings.lua for the two reads.
local SETTINGS_COUNT = 2

local function captureComplete()
  return #capture.replies >= tuneAdvisor.AXIS_COUNT and #capture.settings >= SETTINGS_COUNT
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

-- target: the mcuId the clear was sent to, the FC whose flight was saved (see sendClear)
local function onCleared(target)
  waitFor(0)
  clearPending = false
  lastSeconds[target] = nil  -- that FC holds nothing now
  held[target] = nil         -- so its next reading contains no saved flight
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

-- The clear goes to the FC whose saved flight it erases, and advance() sends it only
-- while that aircraft is connected. The marker reset is keyed by that same FC.
local function sendClear()
  busy = true
  local target = clearMcu
  bus.publish("msp.request", tuneAdvisor.buildClearMessage(function() onCleared(target) end, onError))
end

local onData
local onSetting

local function requestAxis(axis)
  busy = true
  bus.publish("msp.request", tuneAdvisor.buildReadMessage(axis, onData, onError))
end

local function requestSetting(index)
  busy = true
  -- Index 1: MSP_RC_TUNING (Cyclic polarity, ring), index 2: MSP_PID_PROFILE (relax type)
  requireModule("lib/tune_history_settings.lua").request(index, function(data) onSetting(data) end, onError)
end

-- The counts the FC only ever adds to until its statistics are reset
-- (src/main/flight/tune_advisor.c): a reading that holds a saved flight has none
-- smaller than it. Not ffCount, the count of the best feedforward lag: that lag
-- can move.
local GROWING = {"fullCount", "fullSatCount", "releases", "bigRebounds", "shakeCount"}
local BAND_COUNT = 3

-- What a later reading is checked against: per axis the tune and the growing
-- counts, in one array, with the profiles and the date and seconds the flight
-- was saved with
local function heldOf(replies, date, seconds)
  local v, n = {}, 0
  for axis = 1, tuneAdvisor.AXIS_COUNT do
    local a = replies[axis].a
    for _, k in ipairs(tuneHistory.TUNE_KEYS) do n = n + 1; v[n] = a[k] end
    for _, k in ipairs(GROWING) do n = n + 1; v[n] = a[k] or 0 end
    for i = 1, BAND_COUNT do
      n = n + 1; v[n] = a.spBands[i].count
      n = n + 1; v[n] = a.collBands[i].count
    end
  end
  return {pid = link.pidProfile, rate = link.rateProfile, date = date, seconds = seconds, v = v}
end

-- Whether this reading holds the held flight as well: the FC was not cleared
-- since it was saved (a clear it answered drops it, and so does a new link: a
-- pack swapped restarts the FC), it flew on the same known profiles and tune
-- (a tune change restarts its statistics), it counts more seconds, and none of
-- its counts is smaller. False and the first test that failed otherwise.
local function containsHeld(h, replies, seconds)
  if not h then return false, "no saved flight held" end
  local pid, rate = link.pidProfile, link.rateProfile
  if pid == nil or rate == nil or pid ~= h.pid or rate ~= h.rate then return false, "profiles" end
  if seconds <= h.seconds then return false, "seconds" end
  local v, n = h.v, 0
  for axis = 1, tuneAdvisor.AXIS_COUNT do
    local a = replies[axis].a
    for _, k in ipairs(tuneHistory.TUNE_KEYS) do
      n = n + 1
      if a[k] ~= v[n] then return false, "tune" end
    end
    for _, k in ipairs(GROWING) do
      n = n + 1
      if (a[k] or 0) < v[n] then return false, "count" end
    end
    for i = 1, BAND_COUNT do
      n = n + 1
      if a.spBands[i].count < v[n] then return false, "count" end
      n = n + 1
      if a.collBands[i].count < v[n] then return false, "count" end
    end
  end
  return true
end

-- All three axes and both settings are in: save them as one flight, then clear the FC.
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
  -- The settings are read at capture, not during the flight: the FC keeps no
  -- snapshot of them, so a change made after the flight and before this capture
  -- lands on it. Every axis row carries them
  local rc, pid = capture.settings[1], capture.settings[2]
  for i = 1, #replies do
    local a = replies[i].a
    a.polar = rc.cyclic_polarity
    a.ring = rc.cyclic_ring
    a.relaxType = pid.iterm_relax_type
  end
  -- 0: no acro flight. Same as last time: the clear after that flight never
  -- got through and nothing new was flown.
  if seconds > 0 and lastSeconds[mcuId] ~= seconds then
    -- A flight saved before and not cleared off the FC since: this reading may hold it too
    local previous = nil
    local contains, why = containsHeld(held[mcuId], replies, seconds)
    if contains then previous = held[mcuId] end
    local ok, date, marked = tuneHistory.save(mcuId, capture.modelName, replies, previous)
    if not ok then
      -- The replies are kept and only the write is tried again: no MSP, so
      -- not counted against MAX_FAILURES
      print("[tune_history] cannot write " .. tuneHistory.path(mcuId))
      waitFor(RETRY_SECONDS)
      return
    end
    lastSeconds[mcuId] = seconds
    held[mcuId] = heldOf(replies, date, seconds)
    if marked then
      print("[tune_history] reading holds the saved flight (FC not cleared): saved as containing it")
    elseif previous == nil and why ~= "no saved flight held" then
      print("[tune_history] saved flight not held in this reading (" .. tostring(why) .. ")")
    end
    bus.publish("tune_history.saved", mcuId)
  end
  clearReplies()
  pending = false
  if seconds > 0 then
    clearPending = true
    clearMcu = mcuId
  end
  waitFor(GAP_SECONDS)
end

onData = function(data)
  local replies = capture.replies
  replies[#replies + 1] = data
  if captureComplete() then
    finishCapture()
  else
    waitFor(GAP_SECONDS)
  end
  publishState()
end

onSetting = function(data)
  capture.settings[#capture.settings + 1] = data
  if captureComplete() then
    finishCapture()
  else
    waitFor(GAP_SECONDS)
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
  -- session.mcuId is kept across a disconnect for the held flight. Until this
  -- connection's UID handshake answers, it can still be the previous FC's, so
  -- nothing is read or cleared against it before then.
  if not link.mcuIdReady then return end
  if not (pending or clearPending) or busy or link.armed ~= false or link.connected ~= true then return end
  if not link.mcuId or link.apiVersionSupported == false then return end
  if os.clock() < nextAt then return end

  if pending then
    -- The flight is in the FC of the aircraft that was disarmed. Another aircraft
    -- connected in between does not hold it, so the read waits for this one.
    if pendingMcu and link.mcuId ~= pendingMcu then return end
    -- Another aircraft since the last answer: its axes, not these
    if #capture.replies > 0 and capture.mcuId ~= link.mcuId then clearReplies() end
    if #capture.replies == 0 then
      refusedOnFc = false
      capture.mcuId = link.mcuId
      capture.modelName = modelName()
    end
    if captureComplete() then
      finishCapture()             -- a save that failed, tried again
    elseif #capture.replies < tuneAdvisor.AXIS_COUNT then
      requestAxis(#capture.replies + 1)
    else
      requestSetting(#capture.settings + 1)
    end
  elseif not refusedOnFc and clearMcu == link.mcuId then
    -- the clear goes to the FC that holds the saved flight, and only there
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
    -- the aircraft that was flown: its FC holds this flight, whatever is connected later
    pendingMcu = snapshot.mcuId or link.mcuId
    failures = 0
    clearReplies()
    nextAt = os.clock() + START_SECONDS
  end
  if armed ~= nil then lastArmed = armed end
  -- A new link: a fresh pack restarted the FC, which the radio cannot tell from
  -- the same one, so no saved flight is taken to be held in its next reading
  if snapshot.connected == true and link.connected ~= true then
    for k in pairs(held) do held[k] = nil end
  end
  link.armed = armed
  link.connected = snapshot.connected
  link.pidProfile = snapshot.pidProfile
  link.rateProfile = snapshot.rateProfile
  link.mcuId = snapshot.mcuId
  link.mcuIdReady = snapshot.handshake and snapshot.handshake.mcuId == true or false
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
