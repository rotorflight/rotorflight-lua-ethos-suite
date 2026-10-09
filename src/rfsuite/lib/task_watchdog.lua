-- Stall watchdog for the background task's tick (issue #2363).
--
-- The queue and the scheduler guard each call, so one failure no longer skips
-- the rest of a tick. What is left is a tick that never completes: an error
-- ahead of the heartbeat publish repeats on every tick, while Ethos keeps
-- calling the wakeup (measured in the WASM simulator). The task then stays
-- alive and silent. This module decides when a completed tick has been
-- missing long enough to rebuild the pipeline, and counts how often it has.

local Watchdog = {}

function Watchdog.new(stallSeconds)
  return setmetatable(
    {stallSeconds = stallSeconds, lastBeatAt = nil, revivals = 0},
    {__index = Watchdog})
end

-- A tick that ran its whole pipeline. Only this clears a stall.
function Watchdog:beat(now)
  self.lastBeatAt = now or os.clock()
end

-- A task that has never completed a tick has nothing to rebuild yet.
function Watchdog:due(now)
  if self.lastBeatAt == nil then return false end
  return ((now or os.clock()) - self.lastBeatAt) >= self.stallSeconds
end

function Watchdog:noteRevival()
  self.revivals = self.revivals + 1
end

return Watchdog
