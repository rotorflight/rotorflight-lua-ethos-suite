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

local BUS_VERSION = 3

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
  local snapshot = {}
  for i = 1, #list do
    snapshot[i] = list[i]
  end

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
  publishDepth = publishDepth + 1
  if publishDepth > maxPublishDepth then
    maxPublishDepth = publishDepth
  end

  for i = 1, #snapshot do
    local ok, err = pcall(snapshot[i], payload)
    if not ok then
      print("[bus] handler error on '" .. topic .. "': " .. tostring(err))
    end
  end

  publishDepth = publishDepth - 1
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
