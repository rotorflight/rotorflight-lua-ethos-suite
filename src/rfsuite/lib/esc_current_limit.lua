-- The speed controller's own current limit, kept for the model so the dashboard can show the
-- current as a share of it (issue #2355).
--
-- Nothing is asked of the flight controller for it. A manufacturer page that has just read
-- the limit from its own parameter block hands it here, and the session stores it for the
-- connected flight controller (tasks/session.lua, model.esc_current_limit.update). A page reads
-- its block on every visit, so a figure already on file is not sent again.
--
-- Amps, whole, always. The three families that report a limit spell it in three units, so each
-- page converts on the way in: AM32 in amps, Scorpion and YGE in hundredths of an amp.

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local bus = requireModule("lib/bus.lua")

local currentConnected = false
local currentMcuId = nil
local currentLimit = nil
-- A limit read while the link is up but the MCU ID is not known yet. It is handed over
-- when the ID arrives, and dropped on disconnect so it cannot reach another connection.
local pendingLimit = nil

bus.subscribe("session.update", function(snapshot)
  if type(snapshot) ~= "table" then
    currentConnected = false
    currentMcuId = nil
    currentLimit = nil
    pendingLimit = nil
    return
  end
  currentConnected = snapshot.connected == true
  currentMcuId = snapshot.mcuId
  currentLimit = snapshot.escCurrentLimit
  if not currentConnected then
    pendingLimit = nil
    return
  end
  if pendingLimit and currentMcuId and currentMcuId ~= "" then
    local limit = pendingLimit
    pendingLimit = nil
    if currentLimit ~= limit then
      bus.publish("model.esc_current_limit.update", {mcuId = currentMcuId, amps = limit})
      currentLimit = limit
    end
  end
end)

local esc_current_limit = {}

-- Whole amps, or nil where the figure is not a limit. Zero is how the families spell "no limit
-- set", so it is never remembered: it would read back as a limit of nought.
function esc_current_limit.normalize(amps)
  local limit = tonumber(amps)
  if limit == nil then return nil end
  limit = math.floor(limit + 0.5)
  if limit <= 0 then return nil end
  return limit
end

-- Hands a limit in amps to the session. Returns true when the figure is on file for the
-- connected flight controller, was just handed over, or is kept until its MCU ID arrives; false
-- when there is no connected flight controller to store it for or the figure is not a limit.
function esc_current_limit.remember(amps)
  local limit = esc_current_limit.normalize(amps)
  if limit == nil then return false end
  if not currentMcuId or currentMcuId == "" then
    if not currentConnected then return false end
    pendingLimit = limit
    return true
  end
  if currentLimit == limit then return true end
  bus.publish("model.esc_current_limit.update", {mcuId = currentMcuId, amps = limit})
  currentLimit = limit
  return true
end

return esc_current_limit
