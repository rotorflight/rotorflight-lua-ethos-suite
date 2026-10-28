-- Run from the repository root with Lua 5.3+: lua bin/tune_history/verify_tune_history.lua
-- Drives the real tasks/tune_history.lua, lib/tune_history.lua and
-- lib/msp_tune_advisor.lua with a mocked bus and an in-memory LOGS: drive.
-- Pins the capture (each disarm saved as one flight, then the FC cleared;
-- only the last 5 flights kept; a disarm during a link loss captured on
-- reconnect; firmware without the tune advisor left alone), its pacing (a
-- wait after the disarm and between requests, a failed axis asked again on
-- its own, at most three link errors per disarm) and the page's aggregate
-- (only flights on the newest tune, counts added, ratios weighted).

local ROOT = "src/rfsuite/"

local failures, checks = 0, 0
local function check(label, ok, detail)
  checks = checks + 1
  if ok then
    print("  ok    " .. label)
  else
    failures = failures + 1
    print("  FAIL  " .. label)
    if detail then print("        " .. tostring(detail)) end
  end
end

-- In-memory LOGS: files; everything else is the real filesystem.
local files = {}
local realOpen = io.open
io.open = function(path, mode)
  if type(path) == "string" and path:sub(1, 5) == "LOGS:" then
    if files[path] == nil then return nil end
    return {close = function() end}
  end
  return realOpen(path, mode)
end
os.mkdir = function() end
local realRemove = os.remove
os.remove = function(path)
  if type(path) == "string" and path:sub(1, 5) == "LOGS:" then files[path] = nil; return true end
  return realRemove(path)
end

local iniWrites = {}
local cache = {
  ["lib/ini.lua"] = {
    save_ini_file = function(path, data) iniWrites[#iniWrites + 1] = {path, data}; files[path] = "ini"; return true end,
    load_file_as_string = function(path) return files[path] end,
  },
  ["lib/atomic_write.lua"] = {write = function(path, data) files[path] = data; return true end},
}
package.loaded["rfsuite.lib.require"] = function(path)
  if cache[path] == nil then
    local result = assert(loadfile(ROOT .. path))()
    cache[path] = result == nil and true or result
  end
  return cache[path]
end
local requireModule = package.loaded["rfsuite.lib.require"]

local tuneAdvisor = requireModule("lib/msp_tune_advisor.lua")
local tuneHistory = requireModule("lib/tune_history.lua")

-- Each reply is the simulator fixture with these overrides
local reply = {seconds = 147, F = 100}
local realDecode = tuneAdvisor.decode
tuneAdvisor.decode = function(buf)
  local data = realDecode(buf)
  data.seconds = reply.seconds
  data.a.F = reply.F
  return data
end

local clock = 0
os.clock = function() return clock end

local MCU = "abc123"
local HISTORY = "LOGS:/rfsuite/tune/" .. MCU .. "/history.csv"

local handlers, requests, saved, states, task
local function load()
  handlers, requests, saved, states = {}, {}, {}, {}
  for k in pairs(files) do files[k] = nil end
  for i = #iniWrites, 1, -1 do iniWrites[i] = nil end
  local bus = {
    subscribe = function(topic, fn) handlers[topic] = fn end,
    publish = function(topic, message)
      if topic == "msp.request" then requests[#requests + 1] = message end
      if topic == "tune_history.saved" then saved[#saved + 1] = message end
      if topic == "tune_history.state" then states[#states + 1] = message end
    end,
  }
  -- The module takes lib/bus.lua from the require cache
  cache["lib/bus.lua"] = bus
  task = assert(loadfile(ROOT .. "tasks/tune_history.lua"))()
end

local function update(fields)
  local snapshot = {connected = true, mcuId = MCU, craftName = "Wing", fcVersion = "4.7.0"}
  for k, v in pairs(fields) do snapshot[k] = v end
  if fields.mcuId == false then snapshot.mcuId = nil end
  handlers["session.update"](snapshot)
end

-- Runs the clock forward in half-second session updates for `seconds`
-- (default 30), answering each request as it goes out. `fail` maps a request
-- name to {n = times, reason = errorHandler reason}: that many of its sends
-- fail instead. `limit` stops after that many requests. Returns what was asked,
-- e.g. "roll,pitch,yaw,clear", and the clock at each request.
local NAMES = {"roll", "pitch", "yaw"}
local function pump(fail, limit, seconds)
  local asked, times = {}, {}
  local stopAt = clock + (seconds or 30)
  while clock < stopAt and not (limit and #asked >= limit) do
    clock = clock + 0.5
    update({isArmed = false})
    while requests[1] and not (limit and #asked >= limit) do
      local msg = table.remove(requests, 1)
      local name = msg.command == tuneAdvisor.CLEAR_COMMAND and "clear" or NAMES[msg.payload[1] + 1]
      asked[#asked + 1] = name
      times[#times + 1] = clock
      local f = fail and fail[name]
      if f and f.n > 0 then
        f.n = f.n - 1
        msg.errorHandler(f.reason)
      else
        msg.processReply(msg, msg.simulatorResponse)
      end
    end
  end
  return table.concat(asked, ","), times
end

local function lines()
  local out = {}
  for line in (files[HISTORY] or ""):gmatch("[^\n]+") do out[#out + 1] = line end
  return out
end

local function fly(seconds, f)
  reply.seconds, reply.F = seconds, f or 100
  clock = clock + 60
  update({isArmed = true})
  update({isArmed = false})
  return pump()
end

-- Disarms, then lets the start wait pass: that update sends the first read
local function disarmAndWait()
  update({isArmed = true})
  update({isArmed = false})
  clock = clock + 5
  update({isArmed = false})
end

local function drop()
  for j = #requests, 1, -1 do requests[j] = nil end
end

do
  load()
  update({isArmed = false})
  update({isArmed = true})
  check("nothing is asked while armed", #requests == 0, #requests .. " requests")
  local disarmedAt = clock
  update({isArmed = false})
  check("nothing is asked straight after the disarm", #requests == 0, #requests .. " requests")
  local asked, times = pump()
  check("a disarm reads roll, pitch and yaw, then clears the FC", asked == "roll,pitch,yaw,clear", asked)
  local spaced = times[1] ~= nil and times[1] - disarmedAt >= 5
  for i = 2, #times do spaced = spaced and times[i] - times[i - 1] >= 2 end
  check("the first read waits 5 s, and each request 2 s after the last", spaced,
    table.concat(times, " "))
  local r = lines()
  check("a header and one row per axis are written", #r == 4
    and r[1]:match("^date,flight_seconds,axis,")
    and r[2]:match(",147,roll,70,100,0,10,4,18,24,")
    and r[3]:match(",pitch,") and r[4]:match(",yaw,"), table.concat(r, "\n"))
  local _, commas = r[1]:gsub(",", "")
  local _, rowCommas = r[2]:gsub(",", "")
  check("rows have as many columns as the header", commas == rowCommas, commas .. " vs " .. rowCommas)
  check("the aircraft is named beside its history", #iniWrites == 1
    and iniWrites[1][1] == "LOGS:/rfsuite/tune/" .. MCU .. "/logs.ini"
    and iniWrites[1][2].model.name == "Wing")
  check("the page is told", #saved == 1 and saved[1] == MCU)

  asked = pump()
  check("a disarm is captured once", asked == "", asked)
  check("the page is told reading from the disarm until the clear, then idle",
    table.concat(states, ",") == "idle,reading,idle", table.concat(states, ","))

  local asked0 = fly(0)
  check("a flight with no rate flight saves nothing and clears nothing", asked0 == "roll,pitch,yaw"
    and #lines() == 4, asked0 .. " / " .. #lines() .. " lines")

  for n = 1, 6 do fly(100 + n) end
  r = lines()
  check("only the last 5 flights are kept", #r == 16 and r[2]:match(",102,roll,") and r[14]:match(",106,roll,"),
    #r .. " lines; first " .. tostring(r[2]))
end

do
  load()
  update({isArmed = true})
  update({isArmed = nil, connected = false, mcuId = false})
  clock = clock + 10
  update({isArmed = false, connected = true, mcuId = false})
  check("waits for the aircraft identity", #requests == 0, #requests .. " requests")
  pump()
  check("a disarm during a link loss is captured on reconnect", #lines() == 4, #lines() .. " lines")
end

do
  load()
  disarmAndWait()
  requests[1].errorHandler(true)
  drop()
  local asked = pump()
  check("firmware without the tune advisor is asked once", asked == "" and files[HISTORY] == nil, asked)
end

-- The third answer, and the one that has to differ from a link error: a reply this suite
-- refuses is deterministic. The same bytes come back on every request, so waiting out
-- RETRY_SECONDS buys nothing -- the block below runs the same clock the link-error case
-- above needs before it asks again, and asserts that nothing is asked at all.
do
  load()
  clock = 200
  disarmAndWait()
  requests[1].errorHandler("tune advisor payload version 2, expected 1", true)
  drop()
  update({isArmed = false})
  check("a refused reply is not asked again straight away", #requests == 0, #requests .. " requests")
  clock = 211 -- past RETRY_SECONDS
  update({isArmed = false})
  check("a refused reply is never retried", #requests == 0, #requests .. " requests")
  clock = 217
  update({isArmed = false})
  check("a refused reply stays refused, flight by flight", #requests == 0, #requests .. " requests")
  check("a refused flight is not saved", files[HISTORY] == nil, tostring(files[HISTORY]))
  -- The next DISARM asks again, once: the suite may learn the layout, and a pilot who
  -- reconnects expects the capture to run.
  disarmAndWait()
  check("the next disarm asks once", #requests == 1, #requests .. " requests")
end

do
  load()
  clock = 100
  disarmAndWait()
  requests[1].errorHandler("max_retries")
  drop()
  update({isArmed = false})
  check("a link error waits before asking again", #requests == 0, #requests .. " requests")
  local asked = pump({clear = {n = 1, reason = "timeout"}})
  check("a clear that did not get through is sent again", asked == "roll,pitch,yaw,clear,clear"
    and #lines() == 4, asked .. " / " .. #lines() .. " lines")
end

do
  load()
  update({isArmed = true})
  update({isArmed = false})
  local asked = pump({pitch = {n = 1, reason = "max_retries"}})
  check("a lost axis is asked again on its own", asked == "roll,pitch,pitch,yaw,clear" and #lines() == 4,
    asked .. " / " .. #lines() .. " lines")
end

-- What this pacing fixes: a reply lost on every try kept the MSP queue and the
-- telemetry link busy for as long as the model sat disarmed.
do
  load()
  local asked = fly(147)
  check("(setup) one flight saved", asked == "roll,pitch,yaw,clear", asked)
  clock = clock + 60
  update({isArmed = true})
  update({isArmed = false})
  asked = pump({roll = {n = 99, reason = "max_retries"}}, nil, 120)
  check("three link errors, then nothing until the next disarm", asked == "roll,roll,roll", asked)
  check("the page is told the flight was not read", states[#states] == "failed", table.concat(states, ","))
  update({isArmed = true})
  check("arming ends the failed note", states[#states] == "idle", table.concat(states, ","))
  asked = fly(200)
  check("the next disarm reads again", asked == "roll,pitch,yaw,clear" and #lines() == 7,
    asked .. " / " .. #lines() .. " lines")
end

do
  load()
  update({isArmed = true})
  update({isArmed = false})
  local asked = pump({roll = {n = 5, reason = "cleared"}}, nil, 60)
  check("a cleared queue is not counted as a link error",
    asked == "roll,roll,roll,roll,roll,roll,pitch,yaw,clear", asked)
end

-- The session publishes only when its snapshot changes. The capture's waits
-- must run out on the background task's own clock.
do
  load()
  update({isArmed = true})
  update({isArmed = false})
  local asked = {}
  for _ = 1, 60 do
    clock = clock + 0.5
    task.wakeup()
    while requests[1] do
      local msg = table.remove(requests, 1)
      asked[#asked + 1] = msg.command == tuneAdvisor.CLEAR_COMMAND and "clear" or NAMES[msg.payload[1] + 1]
      msg.processReply(msg, msg.simulatorResponse)
    end
  end
  asked = table.concat(asked, ",")
  check("a quiet session still captures, on the task's clock", asked == "roll,pitch,yaw,clear"
    and #lines() == 4, asked .. " / " .. #lines() .. " lines")
end

-- An FC that restarted between two reads answers with another flight
do
  load()
  reply.seconds = 147
  disarmAndWait()
  local roll = table.remove(requests, 1)
  roll.processReply(roll, roll.simulatorResponse)
  reply.seconds = 0
  local asked = pump()
  check("axes from two flights are not saved as one", asked == "pitch,yaw,roll,pitch,yaw"
    and files[HISTORY] == nil, asked .. " / " .. tostring(files[HISTORY]))
  reply.seconds = 147
end

do
  load()
  disarmAndWait()
  local roll = table.remove(requests, 1)
  roll.processReply(roll, roll.simulatorResponse)
  local asked = pump({pitch = {n = 1, reason = "cleared"}})
  check("a cleared queue drops the axes already read", asked == "pitch,roll,pitch,yaw,clear"
    and #lines() == 4, asked .. " / " .. #lines() .. " lines")
end

do
  load()
  local realSave, saves = tuneHistory.save, 0
  tuneHistory.save = function(...)
    saves = saves + 1
    if saves <= 4 then return false end
    return realSave(...)
  end
  update({isArmed = true})
  update({isArmed = false})
  local asked = pump(nil, nil, 60)
  tuneHistory.save = realSave
  check("a failed write is tried again without reading again, past the link-error limit",
    asked == "roll,pitch,yaw,clear" and saves == 5 and #lines() == 4,
    asked .. " / " .. saves .. " saves / " .. #lines() .. " lines")
end

do
  local msg = tuneAdvisor.buildReadMessage(1, function() end)
  check("a tune read gives up after three sends", msg.maxRetries == 2, tostring(msg.maxRetries))
end

do
  load()
  disarmAndWait()
  requests[1].errorHandler(true)
  drop()
  check("firmware without the tune advisor leaves the page idle", states[#states] == "idle",
    table.concat(states, ","))
end

-- A flight is saved and its clear fails, so a clear stays outstanding. The next flight is
-- refused. The clear must not go out now: it would erase the refused flight on the FC.
do
  load()
  clock = 300
  update({isArmed = true})
  update({isArmed = false})
  local asked = pump({clear = {n = 1, reason = "timeout"}}, 4)
  check("flight one is saved before its clear fails", asked == "roll,pitch,yaw,clear" and #lines() == 4,
    asked .. " / " .. #lines() .. " lines")
  disarmAndWait()
  requests[1].errorHandler("tune advisor payload version 2, expected 1", true)
  drop()
  asked = pump()
  check("a clear is not sent over a refused flight on the FC", asked == "", asked)
  check("the refused flight is not saved", #lines() == 4, #lines() .. " lines")
end

-- The page's aggregate
do
  load()
  fly(60, 100)
  fly(70, 80)
  fly(80, 80)
  local flights = tuneHistory.read(MCU)
  check("the history reads back as flights", #flights == 3 and flights[3].seconds == 80
    and flights[3].axes[1].F == 80 and flights[3].axes[3].P == 100, #flights .. " flights")

  local a, used, seconds = tuneHistory.aggregate(flights, 1)
  local one = flights[3].axes[1]
  check("only flights on the newest tune are combined", used == 2 and seconds == 150 and a.F == 80,
    used .. " flights, " .. seconds .. " s")
  check("counts add up", a.ffCount == 2 * one.ffCount and a.releases == 2 * one.releases
    and a.spBands[1].count == 2 * one.spBands[1].count, a.ffCount)
  check("ratios are weighted means", math.abs(a.ffGain - one.ffGain) < 1e-9
    and math.abs(a.meanRebound - one.meanRebound) < 1e-9, a.ffGain)

  for n = 1, 6 do fly(90 + n, 80) end
  local _, usedMax = tuneHistory.aggregate(tuneHistory.read(MCU), 1)
  check("at most 5 flights are combined", usedMax == 5, usedMax)

  local empty, none = tuneHistory.aggregate({}, 2)
  check("no flights aggregate to zeros", none == 0 and empty.ffCount == 0 and empty.collBands[3].count == 0)

  files[HISTORY] = "some,other,columns\n1,2,3\n"
  check("a file with other columns reads as no flights", #tuneHistory.read(MCU) == 0)
end

print()
print(string.format("%d checks, %d failed", checks, failures))
os.exit(failures == 0 and 0 or 1)
