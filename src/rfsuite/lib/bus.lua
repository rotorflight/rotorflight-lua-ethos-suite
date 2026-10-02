-- Minimal publish/subscribe message bus.
--
-- This is the ONLY channel the system tool, dashboard widget, and background
-- task are allowed to use to talk to each other. None of them may reach into
-- another subsystem's tables directly, and none of them may stash state on a
-- shared global.
--
-- Every subsystem loads this file the same way:
--   local bus = assert(loadfile("lib/bus.lua"))()
-- `loadfile` alone would produce a *new*, independent chunk (and therefore a
-- new, disconnected bus) on every call, since each subsystem is loaded from
-- its own separate file. To keep a single shared instance without resorting
-- to an ad hoc global, this module caches itself once under a namespaced key
-- in Lua's own module registry (`package.loaded`) -- the same mechanism
-- `require()` uses internally. That key holds exactly one thing: this bus
-- table. It is not a place to accumulate unrelated shared state.
--
-- Only selected topics are retained and replayed to new subscribers.
-- "session.update" is retained because late-opening widgets/pages need the
-- current connection/profile snapshot even if the aircraft is idle.
-- "task.status" is retained so the app can tell whether the background task
-- has ever run before it lets pilots open MSP-backed pages. "app.state" is
-- retained so a dashboard widget instantiated (or reloaded) while the
-- full-screen app/tool already happens to be open still learns that
-- immediately, instead of defaulting to "not running" until the next
-- open/close toggle. Transient command topics such as "msp.request" must
-- NOT be retained: those payloads carry
-- per-page callback closures, and retaining the last one would keep a closed
-- page alive after navigation.

local BUS_VERSION = 4

local cached = package.loaded["rfsuite.bus"]
if cached and cached._version == BUS_VERSION then
  return cached
end

local subscribers = {}
local lastPublished = {}
local retainedTopics = {
  ["session.update"] = true,
  ["task.status"] = true,
  ["app.state"] = true,
}

-- Re-entrancy accounting for publish(). See docs/memory-and-module-lifecycle.md
-- section 11 for why this exists and what it does and does not prove.
--
-- A handler runs INSIDE the pcall() of its own publish()'s loop, and a
-- handler is allowed to publish again -- that is the normal case, and two or
-- three levels of it is ordinary (session.update handler -> battery.config.
-- saved -> its handler). A handler that publishes to a topic whose handler
-- publishes back to the first one is not ordinary: it recurses until
-- something stops it.
--
-- What stops it is not a Lua error. In the reference Lua VM every
-- Lua-to-Lua call is one C stack level, so that recursion consumes the
-- FreeRTOS stack of the task the radio happens to be running it on, and an
-- exhausted task stack writes into whatever sits below it in memory rather
-- than unwinding. On Ethos that is ioMutex. The result is a hardfault and a
-- watchdog reset, not a catchable error -- which is exactly why this has to
-- be prevented by construction rather than caught afterwards.
--
-- The limit is deliberately far above any legitimate nesting and far below
-- anything that could threaten a stack. Its job is to make the worst case
-- FINITE, not to be the last level before an overflow: the real budget is
-- still unknown, because what system.getMemoryUsage().mainStackAvailable
-- actually counts is an open question (raised with the Ethos firmware
-- author in rotorflight/rotorflight-lua-ethos-suite#2420). maxPublishDepth
-- publishes the deepest chain actually observed, so this constant can later
-- be set from a measurement instead of from a judgement.
local MAX_PUBLISH_DEPTH = 8

-- Both are plain numbers, not tables: read once per memory log line, and
-- nothing here should allocate to answer a question.
local publishDepth = 0
local maxPublishDepth = 0

-- One iteration copy per nesting level, reused across publishes. See publish()
-- for why slots are cleared as handlers run to prevent closure retention.
-- Bounded by MAX_PUBLISH_DEPTH: a level is created the first time a publish
-- actually runs at it.
local snapshots = {}

local function subscribe(topic, handler)
  local list = subscribers[topic]
  if not list then
    list = {}
    subscribers[topic] = list
  end
  list[#list + 1] = handler

  local last = retainedTopics[topic] and lastPublished[topic] or nil
  if last ~= nil then
    local ok, err = pcall(handler, last)
    if not ok then
      print("[bus] handler error replaying last '" .. topic .. "' to new subscriber: " .. tostring(err))
    end
  end

  return handler
end

local function unsubscribe(topic, handler)
  local list = subscribers[topic]
  if not list then
    return
  end
  for i = #list, 1, -1 do
    if list[i] == handler then
      table.remove(list, i)
    end
  end
end

-- One publish()'s handler loop; see publish() for why it is a separate
-- function run under pcall. Module-level so no closure is built per publish.
local function dispatch(snapshot, count, topic, payload)
  for i = 1, count do
    local handler = snapshot[i]
    snapshot[i] = nil
    if handler then
      local ok, err = pcall(handler, payload)
      if not ok then
        print("[bus] handler error on '" .. topic .. "': " .. tostring(err))
      end
    end
  end
end

local function publish(topic, payload)
  if retainedTopics[topic] then
    lastPublished[topic] = payload
  else
    lastPublished[topic] = nil
  end

  local list = subscribers[topic]
  if not list then
    return
  end
  -- Iterate a copy so a handler unsubscribing mid-publish can't skip entries.
  -- The copy is pooled per nesting level rather than built per publish: this
  -- runs at up to 20 Hz for session.update, and a fresh table every time was the
  -- single largest allocation on that path. One snapshot per level is filled
  -- from scratch on every publish, so the set of handlers a publish sees is
  -- still the one that was subscribed when it started -- a handler
  -- unsubscribing mid-publish keeps its turn in that publish and stops
  -- receiving the next one, exactly as before.
  --
  -- Only indices 1..count are read while filling and iterating. Each slot is
  -- cleared back to nil upon retrieval so the snapshot pool does not retain
  -- closures (and their upvalues, e.g. closed PageRuntime instances) after
  -- publish finishes or subscribers unsubscribe.
  --
  -- In PUC-Rio Lua, assigning nil to table array slots does NOT shrink the
  -- allocated C array (sizearray remains unchanged without a rehash), so
  -- writing 1..count on subsequent publishes still allocates 0.0 bytes.
  --
  -- The depth this publish will run at is unique while it runs, so a handler
  -- that publishes to another topic takes the next level and cannot overwrite
  -- the snapshot the outer loop is walking.

  -- Checked before the increment, so the trip raises with the counter still
  -- balanced. The error unwinds exactly ONE level -- into the pcall() of the
  -- publish() that invoked the offending handler -- so the cycle is cut, that
  -- publish()'s existing handler-error branch reports it through the print
  -- below, and every publish() still decrements on the way back out. It is
  -- loud on purpose: a silently dropped publish is indistinguishable from a
  -- bus that works.
  if publishDepth >= MAX_PUBLISH_DEPTH then
    error("bus.publish recursion limit reached (" .. MAX_PUBLISH_DEPTH ..
      ") while publishing '" .. tostring(topic) .. "'", 0)
  end

  local count = #list
  local snapshot = snapshots[publishDepth]
  if snapshot == nil then
    snapshot = {}
    snapshots[publishDepth] = snapshot
  end
  for i = 1, count do
    snapshot[i] = list[i]
  end

  local depth = publishDepth
  publishDepth = depth + 1
  if publishDepth > maxPublishDepth then
    maxPublishDepth = publishDepth
  end

  -- The loop runs under pcall and the depth is restored by assignment, not
  -- decremented, because an error can be raised outside every handler's own
  -- pcall: Ethos's "Max instructions count reached" fires on whichever
  -- instruction crosses the limit, including this loop's own between handlers.
  -- A plain decrement after the loop would then be skipped, and after
  -- MAX_PUBLISH_DEPTH such aborts every publish -- msp.request included --
  -- would fail until the script reloaded. Restoring the saved depth also
  -- undoes anything a nested publish leaked.
  local ok, err = pcall(dispatch, snapshot, count, topic, payload)
  publishDepth = depth
  if not ok then
    for i = 1, count do snapshot[i] = nil end
    error(err, 0)
  end
end

-- The deepest publish() nesting actually observed, in frames. 0 before
-- anything has been published. Exposed as a function so the counter has
-- exactly one home: a mirrored field on the table would be a second copy
-- that can drift from the one the guard reads.
local function observedMaxPublishDepth()
  return maxPublishDepth
end

local bus = {
  _version = BUS_VERSION,
  subscribe = subscribe,
  unsubscribe = unsubscribe,
  publish = publish,
  maxPublishDepth = observedMaxPublishDepth,
}

package.loaded["rfsuite.bus"] = bus

return bus
