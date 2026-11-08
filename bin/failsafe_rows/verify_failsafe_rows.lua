-- Behaviour check for the Failsafe page's channel rows (#2667): the page shows one row
-- per channel the flight controller reports, and writes only those channels.
--
-- Run it:
--     lua5.4 bin/failsafe_rows/verify_failsafe_rows.lua
--     lua5.4 bin/failsafe_rows/verify_failsafe_rows.lua --self-test
--
-- MSP_RXFAIL_CONFIG answers with one record per active RC channel: 16 on CRSF, 18 on
-- other links. The page used to pad to 18 and draw 18 rows, so on CRSF AUX 12 and 13
-- showed as Auto/1500 and a save could write an index the board does not have.
--
-- Drives the real app/pages/failsafe.lua and the real lib/msp_rxfail_config.lua codec.
-- The bus, the form widgets and the header are stubs. The stub bus answers each read
-- with the reply a board would send, and records every write.
--
-- Against the unpatched page the row checks fail: it draws 18 rows before any reply.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end

local ROOT = scriptDir() .. "/../.."
local SRC = ROOT .. "/src/rfsuite"
local PAGE_PATH = SRC .. "/app/pages/failsafe.lua"

local checks, failures = 0, 0
local function check(label, ok, detail)
  checks = checks + 1
  if not ok then failures = failures + 1 end
  print(string.format("  %s  %s%s", ok and "ok  " or "FAIL", label, (not ok and detail) and ("  (" .. detail .. ")") or ""))
end

local function readFile(path)
  local f = assert(io.open(path, "rb"))
  local data = f:read("*a")
  f:close()
  return data
end

-- ---------------------------------------------------------------------------
-- Stubs
-- ---------------------------------------------------------------------------
local requests = {}
local bus = {
  publish = function(topic, msg)
    if topic == "msp.request" then requests[#requests + 1] = msg end
  end,
  subscribe = function() end,
  unsubscribe = function() end,
}

local headerOpts = nil  -- the callbacks the page gave the header (onSave, onBack, ...)
local headerHandle = {
  setSaveEnabled = function() end, setReloadEnabled = function() end,
  focusSave = function() end, focusMenu = function() end, focusReload = function() end,
}

local rowLabels, numberFields, choiceFields, dialogs
local function resetForm()
  rowLabels, numberFields, choiceFields, dialogs = {}, {}, {}, {}
end
resetForm()

form = {
  clear = function() end,
  invalidate = function() end,
  getFieldSlots = function() return {1, 2} end,
  addLine = function(label)
    rowLabels[#rowLabels + 1] = label
    return {label = label}
  end,
  addChoiceField = function(_, _, options, getter, setter)
    local field = {options = options, get = getter, set = setter}
    function field:enable(on) self.enabled = on end
    choiceFields[#choiceFields + 1] = field
    return field
  end,
  addNumberField = function(_, _, minimum, maximum, getter, setter)
    local field = {min = minimum, max = maximum, get = getter, set = setter}
    function field:enable(on) self.enabled = on end
    function field:suffix() end
    function field:step() end
    numberFields[#numberFields + 1] = field
    return field
  end,
  openDialog = function(opts) dialogs[#dialogs + 1] = opts end,
}

local stubs = {
  ["lib/bus.lua"] = bus,
  ["app/close_key.lua"] = {shouldHandleClose = function() return false end},
  ["app/header.lua"] = {build = function(_, opts)
    headerOpts = opts
    return headerHandle
  end},
  ["app/progress_dialog.lua"] = {open = function() return {value = function() end, close = function() end} end},
  ["lib/msp_eeprom.lua"] = {buildWriteMessage = function(onOk, onErr)
    return {command = 250, processReply = function() if onOk then onOk() end end, errorHandler = onErr}
  end},
  ["app/leave_confirm.lua"] = {args = function(a) return a end},
}

local cache = {}
package.loaded["rfsuite.lib.require"] = function(name)
  if stubs[name] then return stubs[name] end
  if cache[name] == nil then
    cache[name] = assert(loadfile(SRC .. "/" .. name))()
  end
  return cache[name]
end

-- ---------------------------------------------------------------------------
-- A board's reply: one record per channel, mode (U8) then value (U16, little-endian).
-- ---------------------------------------------------------------------------
local function reply(count, mode, value)
  local bytes = {}
  for _ = 1, count do
    bytes[#bytes + 1] = mode or 0
    bytes[#bytes + 1] = value % 256
    bytes[#bytes + 1] = math.floor(value / 256)
  end
  return bytes
end

local function lastRequest(command)
  for i = #requests, 1, -1 do
    if requests[i].command == command then return requests[i] end
  end
  return nil
end

-- Opens the page, answers its read with `count` channels, and returns the page's data.
local READ_COMMAND = 77
local function openAnsweredBy(count)
  resetForm()
  requests = {}
  local page = dofile(PAGE_PATH)
  page.open({})
  local read = lastRequest(READ_COMMAND)
  if read then read.processReply(read, reply(count, 0, 1500)) end
end

local LABEL_AUX12 = "@i18n(app.modules.failsafe.aux12)@"
local LABEL_AUX11 = "@i18n(app.modules.failsafe.aux11)@"

-- ---------------------------------------------------------------------------
-- 1. CRSF: 16 channels answered, 16 rows, and no AUX 12 or 13.
-- ---------------------------------------------------------------------------
print("CRSF board (16 channels)")
do
  openAnsweredBy(16)
  check("a 16-channel reply gives 16 rows", #rowLabels == 16, "rows=" .. #rowLabels)
  check("the last row is AUX 11", rowLabels[#rowLabels] == LABEL_AUX11, "last=" .. tostring(rowLabels[#rowLabels]))
  local shows12 = false
  for _, label in ipairs(rowLabels) do if label == LABEL_AUX12 then shows12 = true end end
  check("AUX 12 is not shown", not shows12)
  check("the first channel reads the board's value (1500)", choiceFields[1] and numberFields[1]
    and numberFields[1].get() == 1500, "value=" .. tostring(numberFields[1] and numberFields[1].get()))
end

-- ---------------------------------------------------------------------------
-- 2. A save writes only the channels the board has: a change to channel 1 is written
--    as index 1, and nothing is written for an index past the reply.
-- ---------------------------------------------------------------------------
print("a save on a 16-channel board")
do
  openAnsweredBy(16)
  -- The pilot sets channel 1 to Set (mode 2) and enters a value.
  choiceFields[1].set(2)
  numberFields[1].set(1100)
  -- Save: the header's Save button opens the confirm dialog, and its OK runs the save.
  headerOpts.onSave()
  local confirm = dialogs[#dialogs]
  check("a save asks for confirmation", confirm ~= nil and confirm.buttons ~= nil)
  if confirm and confirm.buttons then confirm.buttons[1].action() end

  local writes = {}
  for _, msg in ipairs(requests) do
    if msg.command == 78 then
      writes[#writes + 1] = msg
    end
  end
  check("the save writes one channel", #writes == 1, "writes=" .. #writes)
  local maxIndex = 0
  for _, msg in ipairs(writes) do
    if msg.payload and msg.payload[1] + 1 > maxIndex then maxIndex = msg.payload[1] + 1 end
  end
  check("the write is index 1", maxIndex == 1 and writes[1] and writes[1].payload[1] == 0,
    "maxIndex=" .. maxIndex)
  -- Answer the write so the page moves on to the EEPROM save.
  for _, msg in ipairs(writes) do msg.processReply(msg, {}) end
  check("the save ends by writing the EEPROM", lastRequest(250) ~= nil)
end

-- ---------------------------------------------------------------------------
-- 3. Other links: 18 channels answered, 18 rows.
-- ---------------------------------------------------------------------------
print("other links (18 channels)")
do
  openAnsweredBy(18)
  check("an 18-channel reply gives 18 rows", #rowLabels == 18, "rows=" .. #rowLabels)
  check("the last row is AUX 13", rowLabels[#rowLabels] == "@i18n(app.modules.failsafe.aux13)@",
    "last=" .. tostring(rowLabels[#rowLabels]))
end

-- ---------------------------------------------------------------------------
-- self-test: the row count must follow the reply, not a fixed 18.
-- ---------------------------------------------------------------------------
local selfTest = false
for _, a in ipairs(arg or {}) do
  if a == "--self-test" then selfTest = true end
end

if selfTest then
  print()
  print("--self-test: the row checks must go red with a fixed count")
  local source = readFile(PAGE_PATH)
  local mutated, replacements = source:gsub(
    "local count = #fields > 0 and #fields or math.min%(#data%.channels, #CHANNEL_LABELS%)",
    "local count = #CHANNEL_LABELS", 1)
  check("self-test: the row count was found in the page exactly once", replacements == 1,
    "replacements=" .. replacements)
  if replacements == 1 then
    local chunk = assert(load(mutated, "@" .. PAGE_PATH))
    resetForm()
    requests = {}
    local page = chunk()
    page.open({})
    local read = lastRequest(READ_COMMAND)
    if read then read.processReply(read, reply(16, 0, 1500)) end
    check("self-test: with a fixed count a 16-channel board gets 18 rows (the check above goes red)",
      #rowLabels == 18, "rows=" .. #rowLabels)
  end
end

print()
print(string.format("%d checks, %d failed", checks, failures))
os.exit(failures == 0 and 0 or 1)
