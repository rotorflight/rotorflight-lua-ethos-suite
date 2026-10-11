-- Main power lost: the flight pack is gone while the receiver still runs on backup power
-- (#2358). One test for both the audio alert (tasks/audio_events.lua) and the dashboard
-- footer banner (widgets/dashboard.lua). tasks/session.lua evaluates it once per voltage
-- change and publishes the result as session.mainPowerLost, so both read the same flag.
--
-- Three things have to be true together, and the second keeps a model whose pack is not
-- measured at all quiet: the pack reads as gone rather than merely low, it has read a real
-- voltage at some point this connection (the latch), and a BEC voltage is there beside it.
-- Without a BEC voltage there is no evidence anything is still powered.
--
-- The threshold is the same number as the EdgeTX suite's lib/audio.lua
-- (MAIN_POWER_LOST_VOLTS). A disconnected pack reads as no voltage at all, and the lowest a
-- flight pack is taken to is far above it, so nothing a discharge reaches falls inside.

local main_power = {}

-- Below this voltage the pack counts as gone, not merely low.
main_power.THRESHOLD_VOLTS = 1.0

-- The latch is per connection: it turns true once the pack has read a real voltage, and is
-- cleared when the link drops. Create one per owner and clear it with the connection.
function main_power.newLatch()
  return {packSeen = false}
end

-- voltage and bec are numbers or nil. Returns true while the main power is lost.
function main_power.evaluate(voltage, bec, latch)
  if voltage == nil then return false end

  if voltage > main_power.THRESHOLD_VOLTS then
    latch.packSeen = true
    return false
  end

  if not latch.packSeen then return false end

  if bec == nil or bec <= 0 then return false end

  return true
end

return main_power
