-- Run from the repository root with Lua 5.3+: lua bin/tune_history/verify_tune_history.lua
-- Drives the real tasks/tune_history.lua and lib/msp_tune_advisor.lua with a
-- mocked bus and an in-memory LOGS: drive. Pins when a disarm is captured:
-- all three axes in one append, nothing for a flight with no new rate data,
-- a disarm during a link loss still captured on reconnect, and firmware
-- without the tune advisor asked once and then left alone.

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

-- In-memory files for LOGS: paths; everything else is the real filesystem.
local files = {}
local realOpen = io.open
local function memFile(path, mode)
  local f = {}
  function f:write(...)
    for i = 1, select("#", ...) do files[path] = files[path] .. tostring(select(i, ...)) end
    return self
  end
  function f:flush() end
  function f:close() end
  if mode:sub(1, 1) == "r" then
    if files[path] == nil then return nil end
  elseif mode:sub(1, 1) == "w" then
    files[path] = ""
  else
    files[path] = files[path] or ""
  end
  return f
end
io.open = function(path, mode)
  mode = mode or "r"
  if type(path) == "string" and path:sub(1, 5) == "LOGS:" then return memFile(path, mode) end
  return realOpen(path, mode)
end
os.mkdir = function() end

local iniWrites = {}
local cache = {
  ["lib/ini.lua"] = {save_ini_file = function(path, data) iniWrites[#iniWrites + 1] = {path, data}; return true end},
}
package.loaded["rfsuite.lib.require"] = function(path)
  if cache[path] == nil then
    local result = assert(loadfile(ROOT .. path))()
    cache[path] = result == nil and true or result
  end
  return cache[path]
end

local tuneAdvisor = package.loaded["rfsuite.lib.require"]("lib/msp_tune_advisor.lua")
local realDecode = tuneAdvisor.decode
local seconds = 147
tuneAdvisor.decode = function(buf)
  local data = realDecode(buf)
  data.seconds = seconds
  return data
end

local clock = 0
os.clock = function() return clock end

local MCU = "abc123"
local HISTORY = "LOGS:/rfsuite/tune/" .. MCU .. "/history.csv"

local handlers, requests
local function load()
  handlers, requests = {}, {}
  for k in pairs(files) do files[k] = nil end
  for i = #iniWrites, 1, -1 do iniWrites[i] = nil end
  local bus = {
    subscribe = function(topic, fn) handlers[topic] = fn end,
    publish = function(topic, message)
      if topic == "msp.request" then requests[#requests + 1] = message end
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
-- answer queues; returns the axes asked for.
local function answerAll()
  local axes = {}
  local i = 1
  while requests[i] do
    local msg = requests[i]
    axes[#axes + 1] = msg.payload[1] + 1
    msg.processReply(msg, msg.simulatorResponse)
    i = i + 1
  end
  for j = #requests, 1, -1 do requests[j] = nil end
  return axes
end

local function rows()
  local text = files[HISTORY]
  if not text then return {} end
  local out = {}
  for line in text:gmatch("[^\n]+") do out[#out + 1] = line end
  return out
end

do
  load()
  seconds = 147
  update({isArmed = false})
  update({isArmed = true})
  check("nothing is asked while armed", #requests == 0, #requests .. " requests")
  update({isArmed = false})
  local axes = answerAll()
  check("a disarm reads roll, pitch and yaw in turn",
    #axes == 3 and axes[1] == 1 and axes[2] == 2 and axes[3] == 3, table.concat(axes, ","))
  local r = rows()
  check("a header and one row per axis are written", #r == 4
    and r[1]:match("^date,flight_seconds,axis,")
    and r[2]:match(",147,roll,50,100,0,10,4,36,72,")
    and r[3]:match(",pitch,") and r[4]:match(",yaw,"), table.concat(r, "\n"))
  local _, commas = r[1]:gsub(",", "")
  local _, rowCommas = r[2]:gsub(",", "")
  check("rows have as many columns as the header", commas == rowCommas, commas .. " vs " .. rowCommas)
  check("the aircraft is named beside its history", #iniWrites == 1
    and iniWrites[1][1] == "LOGS:/rfsuite/tune/" .. MCU .. "/logs.ini"
    and iniWrites[1][2].model.name == "Wing")
  local inTelemetry = nil
  for path in pairs(files) do
    if path:find("/telemetry/", 1, true) then inTelemetry = path end
  end
  check("nothing lands among the flight logs", inTelemetry == nil, inTelemetry)

  update({isArmed = false})
  check("a disarm is captured once", #requests == 0, #requests .. " requests")

  update({isArmed = true})
  update({isArmed = false})
  answerAll()
  check("a flight with no new rate data adds nothing", #rows() == 4, #rows() .. " lines")

  seconds = 300
  update({isArmed = true})
  update({isArmed = false})
  answerAll()
  r = rows()
  check("the next flight appends below, without a second header", #r == 7
    and r[5]:match(",300,roll,") and not r[5]:match("^date"), #r .. " lines")
end

do
  load()
  update({isArmed = true})
  update({isArmed = nil, connected = false, mcuId = false})
  update({isArmed = false, connected = true, mcuId = false})
  check("waits for the aircraft identity", #requests == 0, #requests .. " requests")
  update({isArmed = false})
  answerAll()
  check("a disarm during a link loss is captured on reconnect", #rows() == 4, #rows() .. " lines")
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
  answerAll()
  check("and then captures", #rows() == 4, #rows() .. " lines")
end

print()
print(string.format("%d checks, %d failed", checks, failures))
os.exit(failures == 0 and 0 or 1)
