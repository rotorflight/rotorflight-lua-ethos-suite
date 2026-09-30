-- Running minimum of system.getMemoryUsage().mainStackAvailable.
--
-- Why a minimum and not the instantaneous value: the question this instrument
-- exists to answer is how close the radio has EVER come to the edge of the
-- main stack. An instantaneous reading cannot answer that -- it is a snapshot
-- of one moment, and the interesting moment is the worst one. The minimum is
-- monotonic, which also makes it cheap to trust: one comparison per sample,
-- no allocation, and a number that only ever goes down.
--
-- What it is NOT: a bytes-of-headroom figure that can be compared against a
-- stack size. What system.getMemoryUsage().mainStackAvailable counts is an
-- open question, raised with the Ethos firmware author in
-- rotorflight/rotorflight-lua-ethos-suite#2420. Whatever the field turns out
-- to be, "the smallest value it has ever reported" is a well-defined
-- quantity in the meantime, and it is the quantity a high-water-mark style
-- stack check would compare against. A figure whose unit is unknown is still
-- worth collecting; a figure that is silently redefined to 0 is not.
--
-- Why this is not in lib/memstats.lua: that module is deliberately loaded
-- lazily, inside the system tool's own lifecycle (see #2421), and the only
-- caller of this one is the background task, which runs from boot. Routing
-- the minimum through memstats would mean loading memstats at boot -- 2.9 kB
-- of permanently retained code for a module that does nothing in 99 % of
-- sessions, which is exactly the cost #2421 removed. This file is loaded at
-- its call site instead, and it is small enough that the difference is worth
-- naming in a review rather than hiding in a module boundary.
--
-- lib/memstats.lua's one-shot print() line is deliberately left alone. It is
-- a different instrument with a different purpose -- "how much RAM right
-- now", at a spot of interest -- and a second, independently tracked "minimum"
-- in the same codebase would be two sources for one word. This file is the
-- only place that number is defined.
if package.loaded["rfsuite.lib.stack_probe"] then
  return package.loaded["rfsuite.lib.stack_probe"]
end

local stack_probe = {}

-- nil means "no reading yet", which is deliberately distinct from 0. The
-- caller must pass the raw field, NOT the `or 0` fallback the print lines
-- use: on a firmware that does not report the field at all, `or 0` would
-- feed a zero into the minimum and pin it there for the rest of the session,
-- producing a confident-looking "0.0KB" that means nothing.
local minimum

-- bytes is expected in bytes, matching system.getMemoryUsage(). Non-numeric
-- and nil are ignored rather than coerced, for the reason above.
function stack_probe.note(bytes)
  if type(bytes) ~= "number" then return end
  if minimum == nil or bytes < minimum then
    minimum = bytes
  end
end

-- Returns the smallest value ever noted, or nil if nothing has been noted
-- yet. A number, never a table: this is read once per memory log line.
function stack_probe.minimum()
  return minimum
end

-- Called from the background task's init(), so a reloaded task (a model
-- switch reloads the task) starts a fresh window instead of reporting a
-- minimum from a previous life. Only resets if the module has been loaded,
-- which it may not have been yet on a first boot that never logged.
function stack_probe.reset()
  minimum = nil
end

-- The stack half of the [bgtask mem] line, built here rather than in
-- tasks/background.lua for one reason: this is the string that actually ships,
-- so it can be asserted on directly. Testing a copy of a format string in a
-- harness proves the copy.
--
-- maxPublishDepth is passed in rather than read from lib/bus.lua so this
-- module stays independent of the bus; the caller already has the bus.
--
-- Returns a "-" for the minimum while nothing has been noted, so a reader can
-- tell "not measured yet" from "measured as nothing left". That distinction is
-- the whole reason note() ignores a missing field.
function stack_probe.formatStackFields(maxPublishDepth)
  local stackMin = "-"
  if minimum ~= nil then
    stackMin = string.format("%.1fKB", minimum / 1024)
  end
  return string.format("stackMin=%s pubMax=%d", stackMin, maxPublishDepth or 0)
end

package.loaded["rfsuite.lib.stack_probe"] = stack_probe
return stack_probe
