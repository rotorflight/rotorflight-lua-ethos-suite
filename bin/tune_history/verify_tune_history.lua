-- Run from the repository root with Lua 5.3+: lua bin/tune_history/verify_tune_history.lua
-- Drives the real tasks/tune_history.lua, lib/tune_history.lua and
-- lib/msp_tune_advisor.lua with a mocked bus and an in-memory LOGS: drive.
-- Pins the capture (each disarm saved as one flight, then the FC cleared;
-- only the last 5 flights kept; a disarm during a link loss captured on
-- reconnect; firmware without the tune advisor left alone) and the page's
-- aggregate (only flights on the newest tune, counts added, ratios weighted).

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

local handlers, requests, saved
local function load()
  handlers, requests, saved = {}, {}, {}
  for k in pairs(files) do files[k] = nil end
  for i = #iniWrites, 1, -1 do iniWrites[i] = nil end
  local bus = {
    subscribe = function(topic, fn) handlers[topic] = fn end,
    publish = function(topic, message)
      if topic == "msp.request" then requests[#requests + 1] = message end
      if topic == "tune_history.saved" then saved[#saved + 1] = message end
    end,
  }
  -- The module takes lib/bus.lua from the require cache
  cache["lib/bus.lua"] = bus
  assert(loadfile(ROOT .. "tasks/tune_history.lua"))()
end

local function update(fields)
  local snapshot = {connected = true, mcuId = MCU, craftName = "Wing"}
  for k, v in pairs(fields) do snapshot[k] = v end
  if fields.mcuId == false then snapshot.mcuId = nil end
  handlers["session.update"](snapshot)
end

-- Answers every outstanding request in order, including the ones each
-- answer queues; returns what was asked, e.g. {"roll", "pitch", "yaw", "clear"}.
local NAMES = {"roll", "pitch", "yaw"}
local function answerAll()
  local asked = {}
  local i = 1
  while requests[i] do
    local msg = requests[i]
    if msg.command == tuneAdvisor.CLEAR_COMMAND then
      asked[#asked + 1] = "clear"
    else
      asked[#asked + 1] = NAMES[msg.payload[1] + 1]
    end
    msg.processReply(msg, msg.simulatorResponse)
    i = i + 1
  end
  for j = #requests, 1, -1 do requests[j] = nil end
  return table.concat(asked, ",")
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
  return answerAll()
end

do
  load()
  update({isArmed = false})
  update({isArmed = true})
  check("nothing is asked while armed", #requests == 0, #requests .. " requests")
  update({isArmed = false})
  local asked = answerAll()
  check("a disarm reads roll, pitch and yaw, then clears the FC", asked == "roll,pitch,yaw,clear", asked)
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

  update({isArmed = false})
  check("a disarm is captured once", #requests == 0, #requests .. " requests")

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
  update({isArmed = false, connected = true, mcuId = false})
  check("waits for the aircraft identity", #requests == 0, #requests .. " requests")
  update({isArmed = false})
  answerAll()
  check("a disarm during a link loss is captured on reconnect", #lines() == 4, #lines() .. " lines")
end

do
  load()
  update({isArmed = true})
  update({isArmed = false})
  requests[1].errorHandler(true)
  for j = #requests, 1, -1 do requests[j] = nil end
  update({isArmed = false})
  check("firmware without the tune advisor is asked once", #requests == 0 and files[HISTORY] == nil,
    #requests .. " requests")
end

do
  load()
  clock = 100
  update({isArmed = true})
  update({isArmed = false})
  requests[1].errorHandler("max_retries")
  for j = #requests, 1, -1 do requests[j] = nil end
  update({isArmed = false})
  check("a link error waits before asking again", #requests == 0, #requests .. " requests")
  clock = 106
  update({isArmed = false})
  -- the clear fails too: it is sent again, without reading again
  local i = 1
  while requests[i] and requests[i].command ~= tuneAdvisor.CLEAR_COMMAND do
    requests[i].processReply(requests[i], requests[i].simulatorResponse)
    i = i + 1
  end
  requests[i].errorHandler("timeout")
  for j = #requests, 1, -1 do requests[j] = nil end
  clock = 112
  update({isArmed = false})
  local asked = answerAll()
  check("a clear that did not get through is sent again", asked == "clear" and #lines() == 4,
    asked .. " / " .. #lines() .. " lines")
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
