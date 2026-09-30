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
local maximum

-- bytes is expected in bytes, matching system.getMemoryUsage(). Non-numeric
-- and nil are ignored rather than coerced, for the reason above.
--
-- Both extremes are kept, and the pair is what makes the reading
-- interpretable. The field is a live headroom figure: on one radio it read
-- 9 296 B, and the firmware's own [PWR] readout of the same stack accounted
-- for it to within 500 B -- the depth of the [PWR] call itself, taken at a
-- different moment. A live reading at ONE fixed sample point cannot therefore
-- distinguish "the Main task is genuinely at the edge" from "this particular
-- call site happens to sit deep". A minimum reading 0 next to a maximum
-- reading 9 000 says the first; a maximum that also reads 0 says the second.
-- One build cycle separates them, and neither guess survives both outcomes.
function stack_probe.note(bytes)
  if type(bytes) ~= "number" then return end
  if minimum == nil or bytes < minimum then
    minimum = bytes
  end
  if maximum == nil or bytes > maximum then
    maximum = bytes
  end
end

-- The smallest value ever noted, or nil if nothing has been noted yet. A
-- number, never a table: this is read once per memory log line.
function stack_probe.minimum()
  return minimum
end

-- The largest value ever noted, or nil. See note() on why the pair, and not
-- either end alone, is the interpretable quantity.
function stack_probe.maximum()
  return maximum
end

-- Second channel: the same field, read from a different call site.
--
-- The first channel is read from the background task's wakeup. On its own that
-- cannot distinguish "the Main task is at the edge" from "this call site sits
-- deep", because a fixed call site has a fixed depth: minimum, maximum and the
-- latest value all measure the same thing, and none of them knows how deep
-- that thing is. Only a second reading from a second position can say it.
--
-- widgets/dashboard.lua's paint() is that position: one frame below Ethos'
-- dispatcher, structurally the same place as the task wakeup. Two readings of
-- the same field at two known positions answer the question -- if both are 0,
-- the radio is at the edge wherever anyone looks.
local paintLatest
local paintMinimum
local paintMaximum

-- Same input contract as note(): the RAW field, nil and non-numeric ignored,
-- for the same reason. A missing field must stay distinguishable from a zero.
function stack_probe.notePaint(bytes)
  if type(bytes) ~= "number" then return end
  paintLatest = bytes
  if paintMinimum == nil or bytes < paintMinimum then
    paintMinimum = bytes
  end
  if paintMaximum == nil or bytes > paintMaximum then
    paintMaximum = bytes
  end
end

-- Called from the background task's init(), so a reloaded task (a model
-- switch reloads the task) starts a fresh window instead of reporting a
-- minimum from a previous life. Only resets if the module has been loaded,
-- which it may not have been yet on a first boot that never logged.
--
-- The paint channel is reset here too, but NOT from the paint path: the
-- dashboard outlives a task reload, and a stale minimum from before it would be
-- reported as if it belonged to this life of the task.
function stack_probe.reset()
  minimum = nil
  maximum = nil
  paintLatest = nil
  paintMinimum = nil
  paintMaximum = nil
end

-- The stack half of the [bgtask mem] line, built here rather than in
-- tasks/background.lua for one reason: this is the string that actually ships,
-- so it can be asserted on directly. Testing a copy of a format string in a
-- harness proves the copy.
--
-- The extremes are printed as the RAW integers Ethos reports, in bytes, with
-- no division. An earlier version printed "%.1fKB", which is exactly wrong at
-- the only value that matters: 0 bytes and 51 bytes both render as "0.0KB",
-- and those two are the difference between a stack with room and one that is
-- out of it. Ethos derives the field as 4 * STACK_AVAILABLE_WORDS, so the
-- number is a multiple of 4; the word count is bytes/4 for anyone who thinks
-- in the firmware's unit.
--
-- busMaxPublishDepth is passed in rather than read from lib/bus.lua so this
-- module stays independent of the bus; the caller already has the bus. The
-- parameter name is deliberately longer than the field it prints: pubMax is
-- the BUS's nesting counter, one key away from two stack extremes that are a
-- completely different quantity.
--
-- Returns a "-" for an extreme not yet measured, so a reader can tell "not
-- measured" from "measured as nothing left". That distinction is the whole
-- reason note() ignores a missing field.
function stack_probe.formatStackFields(busMaxPublishDepth)
  local stackMin = "-"
  if minimum ~= nil then
    stackMin = string.format("%dB", minimum)
  end
  local stackMax = "-"
  if maximum ~= nil then
    stackMax = string.format("%dB", maximum)
  end
  return string.format("stackMin=%s stackMax=%s pubMax=%d",
    stackMin, stackMax, busMaxPublishDepth or 0)
end

-- The paint site's contribution to the same line. "-", not a number, until the
-- dashboard has actually been painted -- a dashboard that is never shown must
-- not read as "measured, and it was zero", which is a different statement.
function stack_probe.formatPaintFields()
  if paintLatest == nil then return "paintNow=- paintMin=- paintMax=-" end
  return string.format("paintNow=%dB paintMin=%dB paintMax=%dB",
    paintLatest, paintMinimum, paintMaximum)
end

package.loaded["rfsuite.lib.stack_probe"] = stack_probe
return stack_probe
