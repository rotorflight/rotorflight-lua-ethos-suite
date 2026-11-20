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
-- Faults the record's restart must survive: a failed read, a rename that does nothing, a commit
-- that leaves a short file
local faults = {}
local realOpen = io.open
io.open = function(path, mode)
  if type(path) == "string" and path:sub(1, 5) == "LOGS:" then
    if mode == "a" then
      if files[path] == nil then files[path] = "" end
      return {
        write = function(_, ...)
          for i = 1, select("#", ...) do files[path] = files[path] .. tostring(select(i, ...)) end
        end,
        close = function() end,
      }
    end
    if mode == "w" then
      files[path] = ""
      return {
        write = function(_, ...)
          for i = 1, select("#", ...) do files[path] = files[path] .. tostring(select(i, ...)) end
        end,
        close = function() end,
      }
    end
    if files[path] == nil then return nil end
    -- Read handle: read("L") returns the next line with its terminator, as Ethos does
    local text, pos = files[path], 1
    return {
      read = function()
        if faults.read then return nil, "read error" end
        if pos > #text then return nil end
        local stop = text:find("\n", pos, true) or #text
        local line = text:sub(pos, stop)
        pos = stop + 1
        return line
      end,
      close = function() end,
    }
  end
  return realOpen(path, mode)
end
local realRename = os.rename
os.rename = function(from, to)
  if type(from) == "string" and from:sub(1, 5) == "LOGS:" then
    if faults.rename or files[from] == nil then return nil end
    files[to], files[from] = files[from], nil
    return true
  end
  return realRename(from, to)
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
  ["lib/atomic_write.lua"] = {
    write = function(path, data) files[path] = data; return true end,
    stage = function(path) return io.open(path .. ".tmp", "w") end,
    commit = function(_, path)
      files[path], files[path .. ".tmp"] = files[path .. ".tmp"], nil
      if faults.commitShort then files[path] = files[path]:sub(1, 60) end
      return true
    end,
    abort = function(_, path) files[path .. ".tmp"] = nil end,
    discardTemp = function(path) files[path .. ".tmp"] = nil end,
  },
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
check("boot-resident flight history leaves Apply-record code unloaded",
  package.loaded["rfsuite.lib.tune_history_changes"] == nil)

-- Each reply is the simulator fixture with these overrides
local reply = {seconds = 147, F = 100, releases = nil}
local realDecode = tuneAdvisor.decode
tuneAdvisor.decode = function(buf)
  local data = realDecode(buf)
  data.seconds = reply.seconds
  data.a.F = reply.F
  if reply.releases then data.a.releases = reply.releases end
  return data
end

local clock = 0
os.clock = function() return clock end
-- Each flight saved at its own date, as on a radio
os.date = function() return string.format("2026-11-16 %08.1f", clock) end

local MCU = "abc123"
local OTHER = "def456"            -- a second aircraft, for the swap case
local HISTORY = "LOGS:/rfsuite/tune/" .. MCU .. "/history.csv"
local currentMcu = MCU            -- the FC the link is connected to

-- The active profiles every session update reports; false: unknown
local profiles = {pid = 1, rate = 1}
local handlers, requests, saved, states, task
local function load()
  handlers, requests, saved, states = {}, {}, {}, {}
  currentMcu = MCU
  reply.F, reply.releases = 100, nil
  profiles.pid, profiles.rate = 1, 1
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
  local snapshot = {connected = true, mcuId = currentMcu, craftName = "Wing", fcVersion = "4.7.0",
    handshake = {mcuId = true}, pidProfile = profiles.pid or nil, rateProfile = profiles.rate or nil}
  for k, v in pairs(fields) do snapshot[k] = v end
  if fields.mcuId == false then snapshot.mcuId = nil end
  handlers["session.update"](snapshot)
end

-- Runs the clock forward in half-second session updates for `seconds`
-- (default 30), answering each request as it goes out. `fail` maps a request
-- name to {n = times, reason = errorHandler reason}: that many of its sends
-- fail instead. `limit` stops after that many requests. Returns what was asked,
-- e.g. "roll,pitch,yaw,clear", and the clock at each request.
-- The two settings reads (issues #2639, #2640, #2642) are answered too, but are
-- kept out of that list: they are in lastSettings ("rc,pid"), so the advisor
-- sequence and its limits read as before.
local NAMES = {"roll", "pitch", "yaw"}
local SETTINGS = {[111] = "rc", [94] = "pid"}
local lastSettings = ""
local function pump(fail, limit, seconds)
  local asked, times, settings = {}, {}, {}
  local stopAt = clock + (seconds or 30)
  while clock < stopAt and not (limit and #asked >= limit) do
    clock = clock + 0.5
    update({isArmed = false})
    while requests[1] and not (limit and #asked >= limit) do
      local msg = table.remove(requests, 1)
      if SETTINGS[msg.command] then
        settings[#settings + 1] = SETTINGS[msg.command]
        msg.processReply(msg, msg.simulatorResponse)
      else
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
  end
  lastSettings = table.concat(settings, ",")
  return table.concat(asked, ","), times
end

local function lines()
  local out = {}
  for line in (files[HISTORY] or ""):gmatch("[^\n]+") do out[#out + 1] = line end
  return out
end

local function fly(seconds, f)
  reply.seconds, reply.F = seconds, f or reply.F
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
  check("the cyclic and relax settings are read too, in the same flight", lastSettings == "rc,pid", lastSettings)
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
  check("the header names the polar, ring and relax type columns",
    r[1]:find(",s_rate,cyclic_polar,cyclic_ring,iterm_relax_type,", 1, true) ~= nil, r[1])
  check("each row holds the settings the FC answered (polar 0, ring 150, relax OFF)",
    r[2]:find(",0,150,0,", 1, true) ~= nil and r[4]:find(",0,150,0,", 1, true) ~= nil, r[2])
  check("the aircraft is named beside its history", #iniWrites == 1
    and iniWrites[1][1] == "LOGS:/rfsuite/tune/" .. MCU .. "/logs.ini"
    and iniWrites[1][2].model.name == "Wing")
  check("the page is told", #saved == 1 and saved[1] == MCU)

  asked = pump()
  check("a disarm is captured once", asked == "", asked)
  check("the page is told reading from the disarm until the clear, then idle",
    table.concat(states, ",") == "idle,reading,idle", table.concat(states, ","))

  local asked0 = fly(0)
  check("a flight with no acro flight saves nothing and clears nothing", asked0 == "roll,pitch,yaw"
    and #lines() == 4, asked0 .. " / " .. #lines() .. " lines")

  for n = 1, 6 do fly(100 + n) end
  r = lines()
  check("only the last 5 flights are kept", #r == 16 and r[2]:match(",102,roll,") and r[14]:match(",106,roll,"),
    #r .. " lines; first " .. tostring(r[2]))
end

-- Two flights of the same whole number of seconds: the clear after the first one went
-- through, so the FC holds nothing of it, and the second is a flight of its own.
do
  load()
  fly(147)
  local asked = fly(147)
  check("a flight with the same seconds as the one before is saved once that one is cleared",
    asked == "roll,pitch,yaw,clear" and #lines() == 7, asked .. " / " .. #lines() .. " lines")
end

-- The clear of a saved flight is refused once, then another aircraft connects. That
-- aircraft gets neither a clear nor a read: the clear belongs to the FC that holds the
-- saved flight. Back on that aircraft its FC still holds the flight, so a read of the
-- same seconds is not saved again.
do
  load()
  reply.seconds, reply.F = 147, 100
  clock = clock + 60
  update({isArmed = true})
  update({isArmed = false})
  local asked = pump({clear = {n = 1, reason = "link"}}, 4)
  check("a clear refused once is still to go", asked == "roll,pitch,yaw,clear", asked)

  currentMcu = OTHER
  asked = pump(nil, 1)
  check("another aircraft gets neither a clear nor a read", asked == "", asked)

  currentMcu = MCU
  asked = fly(147)
  check("the saved aircraft's FC still holds the flight: the same seconds are not saved again",
    asked == "roll,pitch,yaw,clear" and #lines() == 4, asked .. " / " .. #lines() .. " lines")
end

-- A flight disarmed on one aircraft, the link lost before its capture, and another
-- aircraft connected: the flight is in the FC of the first, so the other is not read.
do
  load()
  reply.seconds, reply.F = 147, 100
  update({isArmed = true})
  update({isArmed = false})
  update({connected = false, isArmed = false})
  currentMcu = OTHER
  update({connected = true, isArmed = false})
  local asked = pump(nil, 1)
  check("after a swap the flight is not read from the other aircraft's FC",
    asked == "" and files["LOGS:/rfsuite/tune/" .. OTHER .. "/history.csv"] == nil, asked)

  currentMcu = MCU
  asked = pump(nil, 4)
  check("back on the disarmed aircraft its flight is read and saved to it",
    asked == "roll,pitch,yaw,clear" and #lines() == 4
      and files["LOGS:/rfsuite/tune/" .. OTHER .. "/history.csv"] == nil, asked .. " / " .. #lines() .. " lines")
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
  check("the page is told the flight is unread, not failed",
    states[#states] == "unread", table.concat(states, ","))
  update({isArmed = true})
  check("arming ends the unread note", states[#states] == "idle", table.concat(states, ","))
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
      -- the settings reads (no payload) are answered, not counted with the advisor's
      if msg.payload or msg.command == tuneAdvisor.CLEAR_COMMAND then
        asked[#asked + 1] = msg.command == tuneAdvisor.CLEAR_COMMAND and "clear" or NAMES[msg.payload[1] + 1]
      end
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
    if saves <= 3 then return false end
    return realSave(...)
  end
  update({isArmed = true})
  update({isArmed = false})
  local asked = pump(nil, nil, 60)
  check("a failed write is retried three times without rereading the FC",
    asked == "roll,pitch,yaw" and saves == 3 and files[HISTORY] == nil,
    asked .. " / " .. saves .. " saves")
  check("the page is told the flight could not be saved",
    states[#states] == "failed", table.concat(states, ","))
  update({isArmed = true})
  check("arming ends the failed-save notice", states[#states] == "idle", table.concat(states, ","))
  update({isArmed = false})
  asked = pump()
  check("the next disarm resets the write limit and saves the held flight",
    asked == "roll,pitch,yaw,clear" and saves == 4 and #lines() == 4,
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

-- A settings reply too short for its fields is refused like any other layout the
-- suite does not know: the flight is not saved, and no clear goes out over it.
do
  load()
  clock = 500
  update({isArmed = true})
  update({isArmed = false})
  local asked = pump(nil, 3)
  check("(setup) the three axes are read first", asked == "roll,pitch,yaw", asked)
  -- the next request goes out GAP_SECONDS after the last axis answer
  local rc
  for _ = 1, 20 do
    clock = clock + 0.5
    update({isArmed = false})
    if requests[1] then rc = requests[1] break end
  end
  check("(setup) the cyclic settings read is queued next", rc ~= nil and rc.command == 111,
    tostring(rc and rc.command))
  rc.processReply(rc, {0})
  drop()
  local after = pump()
  check("a short settings reply sends no clear", after == "", after)
  check("a short settings reply saves no flight", files[HISTORY] == nil, tostring(files[HISTORY]))
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

-- Until the reconnecting FC's UID handshake answers, the mcuId kept from the last
-- connection can still be the previous FC's: the owed clear waits, and so does a read.
do
  load()
  reply.seconds, reply.F = 147, 100
  clock = clock + 60
  update({isArmed = true})
  update({isArmed = false})
  local asked = pump({clear = {n = 1, reason = "timeout"}}, 4)
  check("a clear of a saved flight is owed before the reconnect", asked == "roll,pitch,yaw,clear" and #lines() == 4,
    asked .. " / " .. #lines() .. " lines")
  drop()
  for _ = 1, 12 do
    clock = clock + 0.5
    update({isArmed = false, mcuId = MCU, handshake = {mcuId = false}})
  end
  check("a retained mcuId sends no owed clear before the reconnect handshake", #requests == 0, #requests .. " requests")
  drop()
end

print("The Apply record reads back")
do
  local CHANGES = "LOGS:/rfsuite/tune/" .. MCU .. "/changes.csv"
  files[CHANGES] = "date,axis,setting,from,to\n"
    .. "2026-10-01 10:00:00,roll,P,50,60\n"
    .. "2026-10-01 10:00:00,pitch,relaxCutoff,10,8\n"
    .. "not,a,row\n"
  local rows = tuneHistory.readChanges(MCU)
  check("the Apply-record code loads on first page-specific use",
    package.loaded["rfsuite.lib.tune_history_changes"] ~= nil)
  check("each row reads as axis, setting, from, to", #rows == 2 and rows[1].axis == 1 and rows[1].key == "P"
    and rows[1].from == 50 and rows[1].to == 60 and rows[2].axis == 2 and rows[2].to == 8, #rows)
  files[CHANGES] = nil
  check("no file reads as no changes", #tuneHistory.readChanges(MCU) == 0)
  files[CHANGES] = "other,header\n1,2\n"
  check("a foreign file reads as no changes", #tuneHistory.readChanges(MCU) == 0)
  -- logChanges() appends whatever the header says: those rows must still read
  files[CHANGES] = "date;axis;setting\n2026-10-01 10:00:00,roll,P,50,60\n"
  check("rows under another header are still read", #tuneHistory.readChanges(MCU) == 1)
  files[CHANGES] = nil
end

print("Appending an Apply upgrades the recognized legacy CSV header")
do
  local CHANGES = "LOGS:/rfsuite/tune/" .. MCU .. "/changes.csv"
  files[CHANGES] = "date,axis,setting,from,to\n"
    .. "2026-10-01 10:00:00,roll,P,50,60\n"
    .. "2026-10-01 10:01:00,pitch,F,90,80"
  check("a legacy Apply appends successfully", tuneHistory.logChanges(MCU, 1, {
    {key = "P", from = 60, to = 70},
  }, 2))
  local text = files[CHANGES]
  check("the migrated header names pid_profile", text:match("^[^\r\n]*") == "date,axis,setting,from,to,pid_profile")
  check("legacy rows gain an empty profile field", text:find("2026%-10%-01 10:00:00,roll,P,50,60,\n") ~= nil
    and text:find("2026%-10%-01 10:01:00,pitch,F,90,80,\n") ~= nil)
  local rows = tuneHistory.readChanges(MCU)
  check("legacy and appended rows still parse with their profile values", #rows == 3
    and rows[1].pidProfile == nil and rows[2].pidProfile == nil and rows[3].pidProfile == 2, #rows)
  files[CHANGES] = nil
end

print("A change written to another axis is recorded on that axis (issue #2639)")
do
  -- Roll under polar cyclic is advised on the Cyclic (pitch) rates: that row is pitch's
  local CHANGES = "LOGS:/rfsuite/tune/" .. MCU .. "/changes.csv"
  files[CHANGES] = "date,axis,setting,from,to,pid_profile\n"
  check("the Cyclic rate change is appended", tuneHistory.logChanges(MCU, 1, {
    {key = "rcRate", from = 18, to = 14, axis = 2},
    {key = "P", from = 60, to = 70},
  }, 0))
  local rows = tuneHistory.readChanges(MCU)
  check("the Cyclic rate row is recorded on pitch", #rows == 2 and rows[1].axis == 2 and rows[1].key == "rcRate"
    and rows[1].from == 18 and rows[1].to == 14, #rows)
  check("a change with no axis of its own stays on the axis given", rows[2] ~= nil and rows[2].axis == 1
    and rows[2].key == "P", tostring(rows[2] and rows[2].axis))
  files[CHANGES] = nil
end

print("The Apply record is followed only on its own PID profile")
do
  local CHANGES = "LOGS:/rfsuite/tune/" .. MCU .. "/changes.csv"
  files[CHANGES] = "date,axis,setting,from,to,pid_profile\n"
    .. "2026-10-01 10:00:00,roll,P,50,60,1\n"
  local rows = tuneHistory.readChanges(MCU)
  check("the PID profile of each row is read", #rows == 1 and rows[1].pidProfile == 1, tostring(rows[1] and rows[1].pidProfile))
  check("the pilot's own P on the same profile is the one before the Apply",
    tuneHistory.pilotValue(rows, 1, "P", 60, 1) == 50, tostring(tuneHistory.pilotValue(rows, 1, "P", 60, 1)))
  check("another PID profile's Apply is not followed", tuneHistory.pilotValue(rows, 1, "P", 60, 2) == 60,
    tostring(tuneHistory.pilotValue(rows, 1, "P", 60, 2)))
  files[CHANGES] = "date,axis,setting,from,to\n2026-10-01 10:00:00,roll,P,50,60\n"
  local legacyRows = tuneHistory.readChanges(MCU)
  check("a legacy row without a profile is followed when the active profile is known",
    tuneHistory.pilotValue(legacyRows, 1, "P", 60, 1) == 50)
  check("a legacy row without a profile is followed when the active profile is unknown",
    tuneHistory.pilotValue(legacyRows, 1, "P", 60, nil) == 50)
  files[CHANGES] = "date,axis,setting,from,to,pid_profile\n"
    .. "2026-10-01 10:00:00,roll,P,50,60,1\n"
  check("with no active PID profile known, the Apply record is still followed", tuneHistory.pilotValue(
    tuneHistory.readChanges(MCU), 1, "P", 60, nil) == 50)
  files[CHANGES] = nil
end

-- A reading that holds the saved flight (issue: the FC was not cleared after the save).
-- Flight one is 140 s; the FC is not cleared, so the next reading holds 140 + 60 = 200 s.
print("A reading that holds the saved flight")

local function marks()
  local n = 0
  for _, line in ipairs(lines()) do
    if line:match("^contains,") then n = n + 1 end
  end
  return n
end

local function savedSeconds()
  local out = {}
  for _, f in ipairs(tuneHistory.read(MCU)) do out[#out + 1] = tostring(f.seconds) end
  return table.concat(out, ",")
end

local function combined()
  local _, used, seconds = tuneHistory.aggregate(tuneHistory.read(MCU), 1)
  return used, seconds
end

local function seen()
  local used, seconds = combined()
  return savedSeconds() .. " saved, " .. marks() .. " marks, " .. used .. " flights / " .. seconds .. " s combined"
end

-- Flies flight one (140 s) and saves it with its clear not done: `how` is "arm" (the clear
-- dropped by the queue, then an arm) or "fail" (three clears fail). `between` runs after
-- the save, before the next flight. The next reading holds `next` seconds (default 200).
-- `earlier`: a normal flight of 100 s first.
-- Flies `seconds` and saves it with its clear not done (see heldCase)
local function flyUncleared(seconds, how)
  reply.seconds = seconds
  clock = clock + 60
  update({isArmed = true})
  update({isArmed = false})
  if how == "fail" then
    pump({clear = {n = 3, reason = "timeout"}}, nil, 60)
  else
    pump({clear = {n = 1, reason = "cleared"}}, 4)
  end
end

local function heldCase(how, between, nextSeconds, earlier)
  load()
  if earlier then fly(100) end
  flyUncleared(140, how)
  if between then between() end
  return fly(nextSeconds or 200)
end

do
  local asked = heldCase("arm", nil, nil, true)
  local used, seconds = combined()
  check("armed again before the clear: the reading is saved marked, then cleared",
    asked == "roll,pitch,yaw,clear" and marks() == 1, asked .. " / " .. seen())
  check("armed again before the clear: 2 flights / 300 s with the earlier flight",
    savedSeconds() == "100,140,200" and used == 2 and seconds == 300, seen())
  local r = lines()
  check("the mark follows the new flight's rows and names flight one",
    r[#r]:match("^contains,2026%-11%-16 [%d%.]+,140$") ~= nil and r[#r - 1]:match(",200,yaw,") ~= nil, r[#r])
  local flights = tuneHistory.read(MCU)
  check("read() gives the newest flight what it contains",
    flights[3].contains and flights[3].contains.date == flights[2].date and flights[3].contains.seconds == 140
      and flights[2].contains == nil, tostring(flights[3].contains))
end

do
  heldCase("fail", nil, nil, true)
  local used, seconds = combined()
  check("three clears failed: 2 flights / 300 s with the earlier flight",
    marks() == 1 and used == 2 and seconds == 300, seen())
end

do
  heldCase("arm", function()
    update({connected = false, isArmed = false})
    update({connected = true, isArmed = true})
  end)
  local used, seconds = combined()
  check("after a new link the reading is saved unmarked, as before (2 flights / 340 s)",
    marks() == 0 and used == 2 and seconds == 340, seen())
end

do
  heldCase("arm", function() reply.F = 90 end)
  check("another tune since the save: no mark", savedSeconds() == "140,200" and marks() == 0, seen())
end

do
  heldCase("arm", function() reply.releases = 0 end)
  local used, seconds = combined()
  check("a count smaller than the saved flight's: no mark, both counted",
    savedSeconds() == "140,200" and marks() == 0 and used == 2 and seconds == 340, seen())
end

do
  heldCase("arm", nil, 120)
  check("no more seconds than the saved flight: no mark", savedSeconds() == "140,120" and marks() == 0, seen())
end

do
  heldCase("arm", function() profiles.pid = 2 end)
  check("another PID profile: no mark", savedSeconds() == "140,200" and marks() == 0, seen())
end

do
  heldCase("arm", function() profiles.pid = false end)
  check("profiles unknown: no mark", savedSeconds() == "140,200" and marks() == 0, seen())
end

do
  heldCase("arm", function() tuneHistory.erase(MCU) end)
  check("history erased since the save: no mark", savedSeconds() == "200" and marks() == 0, seen())
end

do
  -- the clear after flight one answered: the next flight is its own
  load()
  fly(140)
  fly(200)
  check("a clear answered: no mark", marks() == 0, seen())
end

do
  -- flight two holds flight one, flight three holds flight two
  load()
  flyUncleared(140)
  flyUncleared(200)
  fly(260)
  local used, seconds = combined()
  check("chained marks: only the newest reading counts", savedSeconds() == "140,200,260" and marks() == 2
    and used == 1 and seconds == 260, seen())
  fly(30)
  used, seconds = combined()
  check("a later save keeps the marks", marks() == 2 and used == 2 and seconds == 290, seen())
end

do
  heldCase("arm")
  for n = 1, 4 do fly(10 + n) end
  local used, seconds = combined()
  check("a mark whose flight was trimmed away leaves nothing else out",
    savedSeconds() == "200,11,12,13,14" and marks() == 1 and used == 5 and seconds == 250, seen())
end

do
  local header = lines()[1]
  local row = lines()[2]:gsub("^[^,]*,[^,]*,", "")
  files[HISTORY] = table.concat({header,
    "d1,100," .. row:gsub("^[^,]*", "roll"), "d1,100," .. row:gsub("^[^,]*", "pitch"),
    "d1,100," .. row:gsub("^[^,]*", "yaw"),
    "d2,50," .. row:gsub("^[^,]*", "roll"), "d2,50," .. row:gsub("^[^,]*", "pitch"),
    "d2,50," .. row:gsub("^[^,]*", "yaw"), "not a row", "contains,d1,100", ""}, "\n")
  local flights = tuneHistory.read(MCU)
  local _, used, seconds = tuneHistory.aggregate(flights, 1)
  check("a mark after a line that does not read marks nothing",
    #flights == 2 and flights[2].contains == nil and used == 2 and seconds == 150, used .. " / " .. seconds)
end

print()

-- #2807: the record was appended forever and read whole on every page open. Once an Apply leaves
-- it above 16 KiB it is started afresh with one row per setting (and PID profile), and the
-- page's own-P answer must not change for any setting, profile or current value.

print("A restart of the Apply record that goes wrong keeps the full record")
do
  local CHANGES = "LOGS:/rfsuite/tune/" .. MCU .. "/changes.csv"
  local function bigRecord()
    local parts = {"date,axis,setting,from,to,pid_profile\n", "2026-09-01 09:00:00,roll,P,50,60,1\n"}
    for n = 1, 500 do parts[#parts + 1] = string.format("2026-10-01 10:%02d:%02d,pitch,F,%d,%d,2\n", (n // 60) % 60, n % 60, n, n + 1) end
    return table.concat(parts)
  end

  -- Interrupted after the record was moved to the backup: the next Apply puts it back first
  files[CHANGES], files[CHANGES .. ".old"] = nil, "date,axis,setting,from,to,pid_profile\n" .. "2026-09-01 09:00:00,roll,P,50,60,1\n"
  check("the Apply after an interrupted restart is recorded", tuneHistory.logChanges(MCU, 1, {{key = "P", from = 60, to = 72}}, 1))
  check("the backup is put back, not left beside a new record", files[CHANGES .. ".old"] == nil
    and files[CHANGES]:find(",50,60", 1, true) ~= nil)
  check("the pilot's own P still follows the recovered record", tuneHistory.pilotValue(tuneHistory.readChanges(MCU), 1, "P", 72, 1) == 50, tostring(tuneHistory.pilotValue(tuneHistory.readChanges(MCU), 1, "P", 72, 1)))
  files[CHANGES], files[CHANGES .. ".old"] = nil, nil

  -- The record cannot be moved to the backup: no restart, the record stays whole
  files[CHANGES] = bigRecord()
  faults.rename = true
  check("(setup) an Apply on a full record is recorded", tuneHistory.logChanges(MCU, 1, {{key = "P", from = 60, to = 72}}, 1))
  faults.rename = nil
  check("a rename that fails leaves the record whole", #files[CHANGES] > 16 * 1024
    and files[CHANGES .. ".tmp"] == nil and tuneHistory.pilotValue(tuneHistory.readChanges(MCU), 1, "P", 72, 1) == 50, #files[CHANGES])

  -- The new record comes out short: the backup is put back in its place
  files[CHANGES], files[CHANGES .. ".old"] = bigRecord(), nil
  faults.commitShort = true
  tuneHistory.logChanges(MCU, 1, {{key = "P", from = 60, to = 72}}, 1)
  faults.commitShort = nil
  check("a short new record is replaced by the full one", #files[CHANGES] > 16 * 1024
    and files[CHANGES .. ".old"] == nil and tuneHistory.pilotValue(tuneHistory.readChanges(MCU), 1, "P", 72, 1) == 50, #files[CHANGES])

  -- A read that fails is not the end of the file: nothing is restarted
  files[CHANGES], files[CHANGES .. ".old"] = bigRecord(), nil
  local full = files[CHANGES]
  faults.read = true
  tuneHistory.logChanges(MCU, 1, {{key = "P", from = 60, to = 72}}, 1)
  faults.read = nil
  check("a failed read restarts nothing", files[CHANGES .. ".old"] == nil and #files[CHANGES] > #full)
  files[CHANGES], files[CHANGES .. ".old"] = nil, nil
end

print("The Apply record is started afresh once it passes 16 KiB")
do
  local CHANGES = "LOGS:/rfsuite/tune/" .. MCU .. "/changes.csv"
  local AXES = {"roll", "pitch", "yaw"}
  local KEYS = {"P", "F", "B", "rcRate"}
  math.randomseed(2807)
  local parts, last = {"date,axis,setting,from,to,pid_profile\n"}, {}
  for n = 1, 600 do
    local axis, key = math.random(3), KEYS[math.random(#KEYS)]
    local profile = (math.random(7) == 7) and nil or math.random(6)   -- some rows from before the profile column
    local id = axis .. key .. tostring(profile)
    -- mostly chains of the page's own changes, broken now and then by a value set by hand
    local from = (last[id] and math.random(4) > 1) and last[id] or math.random(40, 60)
    local to = from + math.random(-5, 5)
    last[id] = to
    parts[#parts + 1] = string.format("2026-10-01 10:%02d:%02d,%s,%s,%d,%d,%s\n", (n // 60) % 60, n % 60, AXES[axis], key, from, to, profile or "")
  end
  files[CHANGES] = table.concat(parts)
  files[CHANGES .. ".old"] = nil
  local before = files[CHANGES]
  check("(setup) the record is above 16 KiB", #before > 16 * 1024, #before)

  -- What the page answered over the whole record, with this Apply appended
  files[CHANGES] = before .. "2026-11-01 10:00:00,roll,P,60,70,1\n"
  local rows = tuneHistory.readChanges(MCU)
  local expected = {}
  for axis = 1, 3 do
    for _, key in ipairs(KEYS) do
      for profile = 1, 6 do
        for value = 30, 80 do
          expected[#expected + 1] = tuneHistory.pilotValue(rows, axis, key, value, profile)
        end
      end
    end
  end
  files[CHANGES] = before

  check("the Apply is recorded", tuneHistory.logChanges(MCU, 1, {{key = "P", from = 60, to = 70}}, 1))
  local after = files[CHANGES] or ""
  check("the record is started afresh, smaller", #after > 0 and #after < 16 * 1024, #after)
  local backup = files[CHANGES .. ".old"] or ""
  check("the old record is kept as the backup, with this Apply",
    backup:sub(1, #before) == before and backup:sub(#before + 1):find(",roll,P,60,70", 1, true) ~= nil)
  rows = tuneHistory.readChanges(MCU)
  local same, i, firstDiff = true, 0, nil
  for axis = 1, 3 do
    for _, key in ipairs(KEYS) do
      for profile = 1, 6 do
        for value = 30, 80 do
          i = i + 1
          if tuneHistory.pilotValue(rows, axis, key, value, profile) ~= expected[i] then
            same = false
            firstDiff = firstDiff or (axis .. " " .. key .. " " .. value)
          end
        end
      end
    end
  end
  check("the pilot's own value is the same for every setting, profile and current value", same, firstDiff)

  local small = files[CHANGES]
  check("a record below 16 KiB is left as it is", tuneHistory.logChanges(MCU, 1, {{key = "P", from = 60, to = 70}}, 1)
    and files[CHANGES]:sub(1, #small) == small and #files[CHANGES] > #small)

  -- An interrupted restart leaves only the backup
  files[CHANGES .. ".old"] = files[CHANGES]
  files[CHANGES] = nil
  check("with only the backup left, the record still reads", #tuneHistory.readChanges(MCU) > 0)
  files[CHANGES], files[CHANGES .. ".old"] = nil, nil
end

print(string.format("%d checks, %d failed", checks, failures))
os.exit(failures == 0 and 0 or 1)
