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

local BUS_VERSION = 2

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
  for i = 1, #snapshot do
    local ok, err = pcall(snapshot[i], payload)
    if not ok then
      print("[bus] handler error on '" .. topic .. "': " .. tostring(err))
    end
  end
end

local bus = {
  _version = BUS_VERSION,
  subscribe = subscribe,
  unsubscribe = unsubscribe,
  publish = publish,
}

package.loaded["rfsuite.bus"] = bus

return bus
