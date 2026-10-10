-- Run from the repository root with Lua 5.4: lua5.4 bin/tune_advisor_apply/verify_tune_advisor_apply.lua
-- Drives the real app/pages/tune_advisor.lua Apply (header Save) against a
-- mocked FC that answers MSP_PID_TUNING, MSP_PID_PROFILE and MSP_RC_TUNING
-- with the real codecs. Pins what reaches the FC: only the advised fields
-- change, and nothing is written unless every read is complete, the FC still
-- holds the tune the flights were flown on, and the model is disarmed; a
-- failed write never reaches EEPROM; F is never applied without its rates
-- (a percentage-only rates_type applies neither). Also pins that each stage
-- is shown.
-- i18n tags are left unresolved: messages are matched by their key.

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

-- Ethos stand-ins: only what the page touches
system = {getVersion = function() return {simulation = false} end}
FONT_S, LEFT, TEXT_LEFT, CENTERED = 0, 0, 0, 0
lcd = setmetatable({
  getWindowSize = function() return 800, 480 end,
  darkMode = function() return false end,
  getTextSize = function(t) return #t * 6, 12 end,
}, {__index = function() return function() end end})

local dialogs = {}
local progress = nil
local field = setmetatable({}, {__index = function() return function() end end})
form = {
  clear = function() end,
  height = function() return 60 end,
  addLine = function() return field end,
  addChoiceField = function() return field end,
  getFieldSlots = function() return {{x = 0, y = 0, w = 100, h = 30}} end,
  openDialog = function(d) dialogs[#dialogs + 1] = d end,
  openProgressDialog = function(o)
    progress = {msgs = {o.message}, closed = false}
    return {
      value = function() end,
      closeAllowed = function() end,
      message = function(_, m) progress.msgs[#progress.msgs + 1] = m end,
      close = function() progress.closed = true end,
    }
  end,
}

local queue, subs = {}, {}
local saveEnabled, onSave = nil, nil
local logged = {}
local cache = {
  ["lib/bus.lua"] = {
    publish = function(topic, msg) if topic == "msp.request" then queue[#queue + 1] = msg end end,
    subscribe = function(topic, h) subs[topic] = h end,
    unsubscribe = function() end,
  },
  ["app/header.lua"] = {build = function(_, o)
    onSave = o.onSave
    return {setSaveEnabled = function(e) saveEnabled = e end, focusMenu = function() end,
      focusReload = function() end}
  end},
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
local codecs = {
  [112] = requireModule("lib/msp_pid_tuning.lua"),
  [94] = requireModule("lib/msp_pid_profile.lua"),
  [111] = requireModule("lib/msp_rc_tuning.lua"),
}
local WRITE_TO_READ = {[202] = 112, [95] = 94, [204] = 111}
local EEPROM = 250

-- The saved flights: one flight from the advisor's simulator fixture, whose
-- tune is the other codecs' fixtures (Actual rates). Roll: F 120 -> 96, and
-- center sensitivity 18 -> 23 and max rate 24 -> 30.
local flightRatesType = nil       -- overrides the fixture's rates_type when set
local function fixtureFlights()
  local axes = {}
  for axis = 1, 3 do
    local m = tuneAdvisor.buildReadMessage(axis, function(d) axes[axis] = d.a end)
    local buf = {}
    for i, b in ipairs(m.simulatorResponse) do buf[i] = b end
    m.processReply(nil, buf)
    if flightRatesType then axes[axis].ratesType = flightRatesType end
  end
  return {{date = "d", seconds = 147, axes = axes}}
end
tuneHistory.read = function() return fixtureFlights() end
tuneHistory.logChanges = function(_, axis, changes) logged[#logged + 1] = {axis = axis, changes = changes} end

-- The FC: each codec's simulator fixture, decoded
local fc
local function resetFc()
  fc = {}
  for cmd, codec in pairs(codecs) do
    local m = codec.buildReadMessage(function() end)
    local buf = {}
    for i, b in ipairs(m.simulatorResponse) do buf[i] = b end
    fc[cmd] = codec.decode(buf)
  end
end

local wakeup
local session = {mcuId = "abc", connected = true, isArmed = false, pidProfile = 0, rateProfile = 0}

local function openPage()
  local page = assert(loadfile(ROOT .. "app/pages/tune_advisor.lua"))()
  page.open({
    setWakeupHandler = function(f) wakeup = f end,
    setPaintHandler = function() end,
    setCleanupHandler = function() end,
    setEventHandler = function() end,
    onBack = function() end,
  })
  subs["session.update"](session)
end

-- Answers one queued request per wakeup, as the radio would. reply(msg) may
-- return "error", or a byte table to send instead.
local function pump(reply)
  local sent = {}
  wakeup()
  while #queue > 0 do
    local m = table.remove(queue, 1)
    sent[#sent + 1] = m.command
    local custom = reply and reply(m)
    if custom == "error" then
      m.errorHandler("timeout")
    elseif type(custom) == "table" then
      m.processReply(nil, custom)
    elseif WRITE_TO_READ[m.command] then
      local r = WRITE_TO_READ[m.command]
      local buf = {}
      for i, b in ipairs(m.payload) do buf[i] = b end
      fc[r] = codecs[r].decode(buf)
      m.processReply(nil, {})
    elseif codecs[m.command] then
      m.processReply(nil, codecs[m.command].encode(fc[m.command]))
    elseif m.command ~= tuneAdvisor.READ_COMMAND then
      m.processReply(nil, {})
    end
    wakeup()
  end
  return sent
end

local function has(list, value)
  for _, v in ipairs(list) do if v == value then return true end end
  return false
end

local function lastMessage()
  return dialogs[#dialogs] and dialogs[#dialogs].message or ""
end

local function applyNow(reply)
  local before = #dialogs
  onSave()
  local confirm = dialogs[#dialogs]
  if #dialogs == before then return nil, "no confirm dialog" end
  confirm.buttons[1].action()
  return pump(reply), confirm
end

-- Snapshot of every field, to tell what a run changed
local function snapshot()
  local copy = {}
  for cmd, data in pairs(fc) do
    copy[cmd] = {}
    for k, v in pairs(data) do if type(v) == "number" then copy[cmd][k] = v end end
  end
  return copy
end

local function changedFields(before)
  local out = {}
  for cmd, data in pairs(before) do
    for k, v in pairs(data) do
      if fc[cmd][k] ~= v then out[#out + 1] = k end
    end
  end
  table.sort(out)
  return table.concat(out, ",")
end

print("Apply writes only the advised fields")
do
  resetFc()
  openPage()
  pump()
  check("Save is enabled with changes to make", saveEnabled == true)
  local before = snapshot()
  local sent, confirm = applyNow()
  local lines = 0
  for _ in confirm.message:gmatch("[^\n]+") do lines = lines + 1 end
  check("the confirm dialog lists F and both rates and asks", lines == 4
    and confirm.message:find("tune_advisor.apply_prompt", 1, true) ~= nil, confirm.message)
  check("roll F and both rates reach the FC", fc[112].roll_f == 96 and fc[111].rcRates_1 == 23
    and fc[111].rates_1 == 30, "F " .. tostring(fc[112].roll_f) .. ", rates " .. tostring(fc[111].rcRates_1)
    .. "/" .. tostring(fc[111].rates_1))
  check("no other field changes", changedFields(before) == "rates_1,rcRates_1,roll_f", changedFields(before))
  check("only the messages holding a change are written", has(sent, 202) and has(sent, 204)
    and not has(sent, 95), table.concat(sent, ","))
  check("the write is committed, then read back", has(sent, EEPROM) and sent[#sent] == 111,
    table.concat(sent, ","))
  local stages = table.concat(progress.msgs, ",")
  check("each stage is shown", stages:find("stage_read", 1, true) and stages:find("stage_write", 1, true)
    and stages:find("stage_save", 1, true) and stages:find("stage_verify", 1, true), stages)
  check("the progress dialog closes", progress.closed)
  check("success is reported", lastMessage():find("tune_advisor.applied", 1, true) ~= nil, lastMessage())
  check("the change is logged with its old value", #logged == 1 and logged[1].axis == 1
    and logged[1].changes[1].from == 120 and logged[1].changes[1].to == 96)
  check("Save is disabled once applied", saveEnabled == false)
end

print("A tune changed since the flights is never overwritten")
do
  openPage()                      -- the same flights, but the FC holds F 96 now
  pump()
  local before = snapshot()
  local sent = applyNow()
  check("nothing is written", changedFields(before) == "" and not has(sent, 202) and not has(sent, EEPROM),
    table.concat(sent, ","))
  check("the pilot is told why", lastMessage():find("tune_advisor.err_changed", 1, true) ~= nil, lastMessage())
end

print("A profile switch during the reads stops it")
do
  resetFc()
  openPage()
  pump()
  local before = snapshot()
  local sent = applyNow(function(m)
    if m.command == 111 then
      session.pidProfile = 1
      subs["session.update"](session)
    end
  end)
  session.pidProfile = 0
  subs["session.update"](session)
  check("nothing is written", changedFields(before) == "" and not has(sent, EEPROM), table.concat(sent, ","))
  check("reported as changed settings", lastMessage():find("tune_advisor.err_changed", 1, true) ~= nil)
end

print("A failed or short read writes nothing")
do
  resetFc()
  openPage()
  pump()
  local before = snapshot()
  local sent = applyNow(function(m) if m.command == 111 then return "error" end end)
  check("a read error writes nothing", changedFields(before) == "" and not has(sent, 202), table.concat(sent, ","))
  check("a read error is reported", lastMessage():find("tune_advisor.err_read", 1, true) ~= nil, lastMessage())

  -- the codecs read a missing byte as 0: a short reply must not pass as a tune of zeros
  sent = applyNow(function(m) if m.command == 112 then return {105, 0, 45} end end)
  check("a short read writes nothing", changedFields(before) == "" and not has(sent, 202), table.concat(sent, ","))
  check("a short read is reported as a failed read", lastMessage():find("tune_advisor.err_read", 1, true) ~= nil,
    lastMessage())
end

print("A failed write is never committed")
do
  resetFc()
  openPage()
  pump()
  local sent = applyNow(function(m) if m.command == 204 then return "error" end end)
  check("no EEPROM commit after a failed write", not has(sent, EEPROM), table.concat(sent, ","))
  check("the failed write is reported", lastMessage():find("tune_advisor.err_write", 1, true) ~= nil, lastMessage())
end

print("A read-back that differs is reported")
do
  resetFc()
  openPage()
  pump()
  local reads = 0
  applyNow(function(m)
    if m.command == 112 then
      reads = reads + 1
      if reads == 2 then return codecs[112].encode(fc[112]) end
    end
    if m.command == 202 then
      m.processReply(nil, {})     -- the FC acks but keeps its value
      return {}
    end
  end)
  check("reported as unconfirmed", lastMessage():find("tune_advisor.err_verify", 1, true) ~= nil, lastMessage())
end

print("Armed or offline, Save is unavailable")
do
  resetFc()
  openPage()
  pump()
  session.isArmed = true
  subs["session.update"](session)
  pump()
  check("disabled while armed", saveEnabled == false)
  session.isArmed, session.connected = false, false
  subs["session.update"](session)
  pump()
  check("disabled while the link is down", saveEnabled == false)
  session.connected = true
end

print("F is never applied without its rates")
do
  -- Betaflight rates: the rate change can only be given as a percentage
  local BETAFLIGHT = requireModule("lib/rate_curve_scale.lua").RATE_TYPE_BETAFLIGHT
  resetFc()
  fc[111].rates_type = BETAFLIGHT
  flightRatesType = BETAFLIGHT
  openPage()
  pump()
  check("nothing to apply when the rates can only be a percentage", saveEnabled == false)
  flightRatesType = nil
end

print()
print(string.format("%d checks, %d failed", checks, failures))
os.exit(failures == 0 and 0 or 1)
