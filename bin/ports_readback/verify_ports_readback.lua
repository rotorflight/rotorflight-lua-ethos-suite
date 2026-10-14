-- Behaviour check for #2497: the Ports page reads the board back after a save,
-- and it no longer reads the receiver configuration it never shows.
--
-- Run it:
--     lua5.4 bin/ports_readback/verify_ports_readback.lua
--
-- What it drives, and why:
--   * The real src/rfsuite/app/pages/ports.lua, the real bus and the real
--     lib/port_labels.lua. The MSP modules are stubs: each message records its kind,
--     and the scenario answers it the way the FC would (processReply on success,
--     errorHandler on refusal).
--   * Opening the page must not read MSP_RX_CONFIG: its value was never used, and
--     the read held up the loading dialog for one round trip.
--   * After the EEPROM write is accepted, the page reads the serial ports back before
--     it finishes and reboots, and the rows show the values the board reports.
--   * If that read-back fails, the page still finishes and reboots (rows as sent).

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  local last = 0
  for i = 1, #path do
    local ch = path:sub(i, i)
    if ch == "/" or ch == string.char(92) then last = i end
  end
  if last == 0 then return "." end
  return path:sub(1, last - 1)
end

local ROOT = scriptDir() .. "/../.."
local SUITE = ROOT .. "/src/rfsuite"

local function resolvePath(name)
  local f = io.open(name, "r")
  if f then f:close() return name end
  return SUITE .. "/" .. name
end

local realLoadfile = loadfile
loadfile = function(path, mode, env)
  if type(path) == "string" then path = resolvePath(path) end
  if env ~= nil then return realLoadfile(path, mode, env)
  elseif mode ~= nil then return realLoadfile(path, mode)
  else return realLoadfile(path) end
end

local function requireModule(name)
  local key = "rfsuite." .. name:gsub("%.lua$", ""):gsub("/", ".")
  local cached = package.loaded[key]
  if cached ~= nil then return cached end
  local chunk, err = loadfile(resolvePath(name))
  if not chunk then error(err) end
  local ok, result = pcall(chunk)
  if not ok then error(result) end
  package.loaded[key] = (result == nil) and true or result
  return package.loaded[key]
end
package.loaded["rfsuite.lib.require"] = requireModule

local failures, checks = 0, 0
local function check(label, ok, detail)
  checks = checks + 1
  if ok then print(string.format("  ok    %s", label))
  else
    failures = failures + 1
    print(string.format("  FAIL  %s", label))
    if detail then print("        " .. tostring(detail)) end
  end
end

local function anything()
  local t = {}
  return setmetatable(t, {
    __index = function() return function() return anything() end end,
    __call = function() return anything() end,
  })
end

-- ---------------------------------------------------------------------------
-- Stubs
-- ---------------------------------------------------------------------------

lcd = anything()
lcd.getWindowSize = function() return 800, 480 end
system = anything()

local choiceCalls = {}                 -- every addChoiceField, in order: {get, set}
local dialogs = {}                     -- every form.openDialog, in order
form = anything()
form.clear = function() end
form.addLine = function() return anything() end
form.getFieldSlots = function() return {{x = 0, y = 0, w = 10, h = 10}} end
form.addChoiceField = function(_, _, _, getter, setter)
  choiceCalls[#choiceCalls + 1] = {get = getter, set = setter}
  return anything()
end
form.addStaticText = function() return anything() end
form.openDialog = function(opts) dialogs[#dialogs + 1] = opts end

local headerOpts = nil
local headerHandle = anything()
package.loaded["rfsuite.app.header"] = {build = function(_, opts) headerOpts = opts; return headerHandle end}
package.loaded["rfsuite.app.close_key"] = {shouldHandleClose = function() return true end}
package.loaded["rfsuite.app.progress_dialog"] = {open = function() return {value = function() end, close = function() end} end}
package.loaded["rfsuite.lib.memstats"] = {print = function() end}

-- Every MSP message the page publishes, in order, each with its kind.
local sent = {}
local function message(kind, onOk, onErr, extra)
  local m = extra or {}
  m.kind = kind
  m.processReply = function(data) if onOk then onOk(data) end end
  m.errorHandler = onErr
  return m
end

local rxReads = 0
package.loaded["rfsuite.lib.msp_rx_config"] = {
  buildReadMessage = function(onOk, onErr)
    rxReads = rxReads + 1
    return message("rxRead", onOk, onErr)
  end,
}
package.loaded["rfsuite.lib.msp_board_info"] = {
  buildReadMessage = function(onOk, onErr)
    return message("boardInfo", onOk, onErr)
  end,
}
package.loaded["rfsuite.lib.msp_serial_config"] = {
  buildReadMessage = function(onOk, onErr)
    return message("serialRead", onOk, onErr)
  end,
  buildWriteMessage = function(port, onOk, onErr)
    return message("serialWrite", onOk, onErr)
  end,
}
package.loaded["rfsuite.lib.msp_eeprom"] = {
  buildWriteMessage = function(onOk, onErr)
    return message("eeprom", onOk, onErr)
  end,
}
package.loaded["rfsuite.lib.msp_reboot"] = {
  buildWriteMessage = function()
    return message("reboot", nil, nil)
  end,
}

local bus = requireModule("lib/bus.lua")
bus.subscribe("msp.request", function(m) sent[#sent + 1] = m end)

local page = requireModule("app/pages/ports.lua")

-- ---------------------------------------------------------------------------
-- Scenario helpers
-- ---------------------------------------------------------------------------

local function kindCount(kind)
  local n = 0
  for _, m in ipairs(sent) do if m.kind == kind then n = n + 1 end end
  return n
end

local function lastMessage()
  return sent[#sent]
end

-- A serial-config reply carries every baud index, whatever the function is.
local function portRow(identifier, functionMask)
  return {identifier = identifier, function_mask = functionMask,
          msp_baud_index = 5, gps_baud_index = 5, blackbox_baud_index = 5, telem_baud_index = 5}
end

local function boardPorts(firstFunction)
  return {ports = {portRow(0, firstFunction), portRow(1, 64)}}
end

local wakeupHandler = nil

-- Opens the page and answers the board-info and the serial read.
local function openAndLoad(firstFunction)
  sent, choiceCalls, dialogs, rxReads = {}, {}, {}, 0
  headerOpts, wakeupHandler = nil, nil
  page.open({
    onBack = function() end,
    setWakeupHandler = function(fn) wakeupHandler = fn end,
  })
  lastMessage().processReply({board_design = "", board_name = "", identifier = 0})   -- boardInfo
  lastMessage().processReply(boardPorts(firstFunction))                              -- serialRead
  -- The unpatched page also reads MSP_RX_CONFIG before it renders. The read is counted
  -- by rxReads above; here it is answered so the rest of the scenario still runs.
  if lastMessage() and lastMessage().kind == "rxRead" then
    lastMessage().processReply({serialrx_provider = 0})
  end
  if wakeupHandler then wakeupHandler() end                                          -- render
end

-- Answers the save: every serial write accepted, then the EEPROM write per `eepromOk`.
local function save(eepromOk)
  headerOpts.onSave()
  local confirm = dialogs[#dialogs]
  if confirm and confirm.buttons then confirm.buttons[1].action() end
  for _ = 1, 20 do
    local m = lastMessage()
    if m == nil or m.kind == "eeprom" then break end
    if m.kind == "serialWrite" then m.processReply() else break end
  end
  local eeprom = lastMessage()
  if eeprom and eeprom.kind == "eeprom" then
    if eepromOk then eeprom.processReply() else eeprom.errorHandler() end
  end
end

-- ---------------------------------------------------------------------------
-- 1. Opening the page reads no receiver configuration
-- ---------------------------------------------------------------------------

print("open")
openAndLoad(0)
check("opening the page reads no MSP_RX_CONFIG", rxReads == 0, "rxReads=" .. rxReads)

-- ---------------------------------------------------------------------------
-- 2. A save reads the board back before it finishes and reboots
-- ---------------------------------------------------------------------------

print("save with read-back")
openAndLoad(0)
choiceCalls[1].set(4)                 -- port 0's function: a real change, the page is dirty
save(true)                            -- every write accepted, then EEPROM accepted
local readBackSent = kindCount("serialRead") >= 2 and lastMessage().kind == "serialRead"
local kinds = {}
for _, m in ipairs(sent) do kinds[#kinds + 1] = m.kind end
check("after an accepted EEPROM write the page reads the serial ports back", readBackSent,
      "sent: " .. table.concat(kinds, " "))
check("the reboot waits for the read-back", kindCount("reboot") == 0,
      "reboots=" .. kindCount("reboot"))

lastMessage().processReply(boardPorts(2))   -- the board reports function 2, not the 4 that was sent
check("the reboot follows the read-back reply", kindCount("reboot") == 1,
      "reboots=" .. kindCount("reboot"))
if wakeupHandler then wakeupHandler() end   -- render the rows the read-back produced
local shown = choiceCalls[#choiceCalls - 3] and choiceCalls[#choiceCalls - 3].get()
check("the rows show the value the board reports, not the value sent", shown == 2,
      "shown=" .. tostring(shown))

-- ---------------------------------------------------------------------------
-- 3. A refused read-back still finishes the save and reboots
-- ---------------------------------------------------------------------------

print("save with a failed read-back")
openAndLoad(0)
choiceCalls[1].set(4)
headerOpts.onSave()
local confirm = dialogs[#dialogs]
if confirm and confirm.buttons then confirm.buttons[1].action() end
for _ = 1, 20 do
  local m = lastMessage()
  if m == nil or m.kind == "eeprom" then break end
  if m.kind == "serialWrite" then m.processReply() else break end
end
lastMessage().processReply()                -- EEPROM accepted
local readBackRequest = lastMessage()
check("a read-back request exists to be refused", readBackRequest and readBackRequest.kind == "serialRead",
      "last=" .. tostring(readBackRequest and readBackRequest.kind))
if readBackRequest and readBackRequest.errorHandler then readBackRequest.errorHandler() end  -- the read-back is refused
check("a failed read-back still reboots the board", kindCount("reboot") == 1,
      "reboots=" .. kindCount("reboot"))

print(string.format("\n%d checks, %d failed", checks, failures))
os.exit(failures == 0 and 0 or 1)
