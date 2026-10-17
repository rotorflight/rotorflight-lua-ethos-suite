-- The 40-slot budget of the Telemetry page (issue #2499).
--
-- The radio has 40 telemetry slots. Two quantities compete for them: the
-- sensors the pilot has switched on (plus the ones the FC locks in native
-- mode), and the native slots the page does not manage, which are kept as they
-- are. The save check and the toggle gate must read the same quantity, or the
-- gate accepts a switch that the save then refuses, with no visible reason.
--
-- Pure on purpose: no form, catalog or runtime. The page passes in the managed
-- count it already computes for the write, so both call sites share one rule.

local budget = {}

-- True when the managed selections plus the kept native slots do not fit.
function budget.overflows(managedCount, unmanagedCount, limit)
  return managedCount + unmanagedCount > limit
end

-- True when one more managed selection would not fit. The toggle gate asks
-- this before it accepts a switch, so the switch that would make the save
-- refuse is refused on the spot.
function budget.overflowsWithOneMore(managedCount, unmanagedCount, limit)
  return budget.overflows(managedCount + 1, unmanagedCount, limit)
end

return budget
