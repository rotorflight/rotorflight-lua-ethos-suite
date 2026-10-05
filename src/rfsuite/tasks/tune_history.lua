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
local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local bus = requireModule("lib/bus.lua")
local tuneAdvisor = requireModule("lib/msp_tune_advisor.lua")
local tuneHistory = requireModule("lib/tune_history.lua")

local RETRY_SECONDS = 5           -- after a link error, before asking again

local lastArmed = nil             -- last known arm state; a link loss (nil) keeps it
local pending = false             -- a disarm has not been captured yet
local clearPending = false        -- saved, the FC not cleared yet
local busy = false                -- a request is out
local retryAt = 0
local capture = {mcuId = nil, modelName = nil, replies = {}}
local lastSeconds = {}            -- by mcuId: flight_seconds of the last flight saved

local function snapshotModelName(snapshot)
  if snapshot.craftName and snapshot.craftName ~= "" then return snapshot.craftName end
  if model and model.name then
    local ok, name = pcall(model.name)
    if ok and name and name ~= "" then return name end
  end
  return "Unknown"
end

local function clearReplies()
  for i = #capture.replies, 1, -1 do capture.replies[i] = nil end
end

local function retryLater()
  busy = false
  retryAt = os.clock() + RETRY_SECONDS
end

local function onCleared()
  busy = false
  clearPending = false
end

-- reason true is the FC's MSP error reply: no tune advisor in this firmware,
-- nothing to capture or clear. Anything else is the link: try again shortly.
local function onError(reason)
  clearReplies()
  if reason == true then
    busy = false
    pending = false
    clearPending = false
    return
  end
  retryLater()
end

local function sendClear()
  busy = true
  bus.publish("msp.request", tuneAdvisor.buildClearMessage(onCleared, onError))
end

local requestAxis

local function onData(data)
  local replies = capture.replies
  replies[#replies + 1] = data
  if #replies < tuneAdvisor.AXIS_COUNT then
    requestAxis(#replies + 1)
    return
  end

  local mcuId, seconds = capture.mcuId, replies[1].seconds
  -- 0: no rate flight. Same as last time: the clear after that flight never
  -- got through and nothing new was flown.
  if seconds > 0 and lastSeconds[mcuId] ~= seconds then
    if not tuneHistory.save(mcuId, capture.modelName, replies) then
      print("[tune_history] cannot write " .. tuneHistory.path(mcuId))
      clearReplies()
      retryLater()
      return
    end
    lastSeconds[mcuId] = seconds
    bus.publish("tune_history.saved", mcuId)
  end
  clearReplies()
  pending = false
  if seconds > 0 then
    clearPending = true
    sendClear()
  else
    busy = false
  end
end

requestAxis = function(axis)
  bus.publish("msp.request", tuneAdvisor.buildReadMessage(axis, onData, onError))
end

local function onSessionUpdate(snapshot)
  if not snapshot then return end
  local armed = snapshot.isArmed
  if armed == true then
    pending = false               -- the next disarm captures this flight too
  elseif armed == false and lastArmed == true then
    pending = true
    retryAt = 0
  end
  if armed ~= nil then lastArmed = armed end

  if not (pending or clearPending) or busy or armed ~= false or snapshot.connected ~= true then return end
  if not snapshot.mcuId or snapshot.apiVersionSupported == false then return end
  if os.clock() < retryAt then return end

  if pending then
    busy = true
    capture.mcuId = snapshot.mcuId
    capture.modelName = snapshotModelName(snapshot)
    requestAxis(1)
  else
    sendClear()
  end
end

bus.subscribe("session.update", onSessionUpdate)

return {}
