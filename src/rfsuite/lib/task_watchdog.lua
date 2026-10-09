-- Stall watchdog for the background task's tick (issue #2363).
--
-- The queue and the scheduler guard each call, so one failure no longer skips
-- the rest of a tick. What is left is a tick that never completes: an error
-- ahead of the heartbeat publish repeats on every tick, while Ethos keeps
-- calling the wakeup (measured in the WASM simulator). The task then stays
-- alive and silent. This module counts ticks that began and did not finish --
-- that failure, not a gap between two calls -- and counts the rebuilds.

local Watchdog = {}

function Watchdog.new(stallSeconds)
  return setmetatable(
    {stallSeconds = stallSeconds, startedAt = nil, revivals = 0},
    {__index = Watchdog})
end

-- The first tick of a stalled run. A later tick leaves the mark alone: the
-- stall began when that first one started, not when the last one did.
function Watchdog:start(now)
  if self.startedAt == nil then self.startedAt = now or os.clock() end
end

-- The tick ran its whole pipeline. A revival counts as one, because the
-- pipeline runs again from there.
function Watchdog:beat()
  self.startedAt = nil
end

-- A task whose last tick finished has nothing to rebuild -- and neither has
-- one Ethos has not called for a while: no tick started, so none failed.
function Watchdog:due(now)
  if self.startedAt == nil then return false end
  return ((now or os.clock()) - self.startedAt) >= self.stallSeconds
end

function Watchdog:noteRevival()
  self.revivals = self.revivals + 1
end

return Watchdog
